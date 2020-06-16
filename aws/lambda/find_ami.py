##python2
import os
import sys
import boto3
import json
import threading
import logging
import urllib3
#from functools import cmp_to_key

CFN_SUCCESS = "SUCCESS"
CFN_FAILED = "FAILED"

class my_version(str):
    def __init__(self, str_version):
        version = str_version.split('.')
        self.major = self.minor = self.patch = 0
        if len(version) >= 1:
            self.major = int(version[0])
        if len(version) >= 2:
            self.minor = int(version[1])
        if len(version) >= 3:
            self.patch = int(version[2])

#input: {'name': 'xx', 'ami_id': 'xx', 'version': 'x.y.z'}
def mycmp(x, y):
    xv = my_version(x['version'])
    yv = my_version(y['version'])
    ret = xv.major - yv.major
    if 0 != ret:
        return ret
    ret = xv.minor - yv.minor
    if 0 != ret:
        return ret
    ret = xv.patch - yv.patch
    return ret

def find_amis(filters):
    client = boto3.client('ec2')
    #resp = client.describe_images(Owners=['aws-marketplace'], Filters=filters)
    resp = client.describe_images(Filters=filters)
    all_images = resp['Images']
    ret_list = []
    for image in all_images:
        ret_list.append({'name':image['Name'], 'ami_id': image['ImageId']})
    return ret_list

def find_custom_ami(ami_name):
    filters = []
    filters.append({'Name': 'name', 'Values': [ami_name]})
    image_list = find_amis(filters)
    if len(image_list) <= 0:
        msg = 'Can not found custom AMI! ami_name: %s' % (ami_name)
        raise Exception(msg)
    image = image_list[0]
    image['version'] = 'x.x.x'
    return image

def find_latest(pay_type, ami_name=None):
    if None != ami_name:
        return find_custom_ami(ami_name)
    filters = []
    filters.append({'Name': 'owner-alias', 'Values': ['aws-marketplace']})
    filters.append({'Name': 'is-public', 'Values': ['true']})
    filters.append({'Name': 'name', 'Values': ['*FortiWeb-AWS-*%s*' % (pay_type)]})
    image_list = find_amis(filters)
    if len(image_list) <= 0:
        msg = 'Can not found latest AMI! type: %s' % pay_type
        raise Exception(msg)
    for image in image_list:
        version = image['name'].split('FortiWeb-AWS-')[1].split(pay_type)[0]
        image['version'] = version
    #image_list.sort(key=cmp_to_key(mycmp))
    image_list.sort(mycmp)
    print('pay_type(%s) ami list: %s' % (pay_type, image_list))
    return image_list[-1]

def find_byol_latest(byol_ami_name=None):
    return find_latest('_BYOL', byol_ami_name)

def find_on_demand_latest(on_demand_ami_name=None):
    return find_latest('_OnDemand', on_demand_ami_name)

def cfn_send(evt, context, responseStatus, respData, reason=''):
    respUrl = evt['ResponseURL']
    print(respUrl)
    respBody = {}
    respBody['Status'] = responseStatus
    respBody['Reason'] = reason + '\nSee the details in CloudWatch:' + context.log_group_name + ',' + context.log_stream_name
    respBody['PhysicalResourceId'] = context.log_stream_name
    respBody['StackId'] = evt['StackId']
    respBody['RequestId'] = evt['RequestId']
    respBody['LogicalResourceId'] = evt['LogicalResourceId']
    respBody['NoEcho'] = None
    respBody['Data'] = respData

    json_respBody = json.dumps(respBody)
    print("Response to cloudformation:\n" + json_respBody)
    headers = {'content-type' : '', 'content-length' : str(len(json_respBody)) }
    try:
        http = urllib3.PoolManager()
        response = http.request('PUT', respUrl, headers=headers, body=json_respBody)
        print("cloudformation status code: %s" % (response.status))
        print("cloudformation return body: %s" %(response.data.decode('utf-8')))
    except Exception as e:
        print("send(..) failed sending response: " + str(e))
        raise

def timeout(event, context):
    logging.error('Time out, failure response to CloudFormation')
    cfn_send(event, context, CFN_FAILED, {}, 'fwb labmda timeout')

def handler(event, context):
    print('event: %s' % json.dumps(event))
    status = CFN_SUCCESS
    respData = {}
    err_msg = 'no error'
    if event['RequestType'] not in ['Create', 'Update']:
        cfn_send(event, context, status, respData, err_msg)
        return
    # make sure we send a failure to CloudFormation if the function is going to timeout
    timer = threading.Timer((context.get_remaining_time_in_millis() / 1000.00) - 0.5, timeout, args=[event, context])
    timer.start()
    rpt = event['ResourceProperties']
    byol_needed = True
    on_demand_needed = True
    byol_ami_name = None
    on_demand_ami_name = None
    if 'BYOLNeeded' in rpt and rpt['BYOLNeeded'].strip().startswith('n'):
        byol_needed = False
    if 'OnDemandNeeded' in rpt and rpt['OnDemandNeeded'].strip().startswith('n'):
        on_demand_needed = False
    if 'BYOLAMIName' in rpt and len(rpt['BYOLAMIName'].lstrip().rstrip()) > 0:
        byol_ami_name = rpt['BYOLAMIName']
    if 'OnDemandAMIName' in rpt and len(rpt['OnDemandAMIName'].lstrip().rstrip()) > 0:
        on_demand_ami_name = rpt['OnDemandAMIName']
    try:
        print('try to find ami id')
        if True == byol_needed:
            print('BYOL needed')
            image_info = find_byol_latest(byol_ami_name)
            respData['LatestBYOLAmiId'] = image_info['ami_id']
            respData['LatestBYOLAmiVersion'] = image_info['version']
        else:
            print('BYOL not needed')
            respData['LatestBYOLAmiId'] = 'i-not-required'
            respData['LatestBYOLAmiVersion'] = '0.0.0'
        if True == on_demand_needed:
            print('OnDemand needed')
            image_info = find_on_demand_latest(on_demand_ami_name)
            respData['LatestOnDemandAmiId'] = image_info['ami_id']
            respData['LatestOnDemandAmiVersion'] = image_info['version']
        else:
            print('OnDemand not needed')
            respData['LatestOnDemandAmiId'] = 'i-not-required'
            respData['LatestOnDemandAmiVersion'] = '0.0.0'
    except Exception as e:
        err_msg = 'exception: %s' % (str(e))
        status = CFN_FAILED
    finally:
        timer.cancel()
    cfn_send(event, context, status, respData, err_msg)

if '__main__' == __name__:
    event = {}
    class fake_context: pass
    fake_context.get_remaining_time_in_millis = lambda self: 2*60*1000
    event['RequestType'] = 'Create'
    event['ResponseURL'] = 'http://127.0.0.1:3000'
    event['StackId'] = 'StackId'
    event['RequestId'] = 'RequestId'
    event['LogicalResourceId'] = 'LogicalResourceId'
    event['ResourceProperties'] = {}
    event['ResourceProperties']['BYOLAMIName'] = ''
    event['ResourceProperties']['OnDemandAMIName'] = ''
    #event['ResourceProperties']['BYOLNeeded'] = 'n'
    event['ResourceProperties']['BYOLNeeded'] = 'y'
    #event['ResourceProperties']['OnDemandNeeded'] = 'n'
    event['ResourceProperties']['OnDemandNeeded'] = 'y'
    context = fake_context()
    context.log_group_name = 'log_group'
    context.log_stream_name = 'log_stream'
    handler(event, context)

