import boto3
import logging
import json
import cfnresponse
from botocore.exceptions import ClientError

class InstanceParam:
    def __init__(self, InsCount, ImageId, InsType, KeyName):
        self.InsCount = InsCount
        self.ImageId = ImageId
        self.InsType = InsType
        self.KeyName = KeyName
    def SetInterfaceSecGroups(self, SecGroups, PublicSubnet):
        self.Interfaces = [{
         'DeviceIndex': 0,
         'AssociatePublicIpAddress': True,
         'Groups': SecGroups,
         'SubnetId': PublicSubnet,
        }
    ]
    def SetTags(self, Tags):
        self.Tags = Tags

    def SetUserData(self,UserData):
        self.UserData= UserData
    def SetSubnet(self, Subnets):
        self.Subnets = Subnets
        self.SubnetCount = len(Subnets)

    def SetIAM(self, arn, profilename):
        self.Iam = {
            'Arn':arn
        }


def GetLicenseFileName(bucket_name, lic_prefix):
    client = boto3.client('s3')
    licenses = []
    response = client.list_objects(Bucket=bucket_name, Prefix=lic_prefix+'license/')

    for item in response['Contents']:
        if item['Key'].find('.lic') != -1:
            licenses.append(item['Key'])
    print(licenses)

    return licenses


def InitInsParam(event, count, lic_files):
    Resource = event['ResourceProperties']
    InsParm = InstanceParam(int(Resource['FortiWebInstancesCount']),
                            Resource['ImageId'],
                            Resource['InstanceType'],
                            Resource['KeyName'])

    Tags = [
                {
                    'ResourceType': 'instance',
                    'Tags':[
                        {
                            'Key': 'group-id',
                            'Value': Resource['FortiWebHAGroupID']
                        },
                        {
                            'Key': Resource['FortiWebHACfName']	+ '-instance',
                            'Value':Resource['FortiWebHACfName']
                        },
                        {
                            'Key':'Name',
                            'Value':Resource['CustomIdentifier'] + '-' + str(count + 1)
                        }
                    ]
                }
          ]
    InsParm.SetTags(Tags)

    SecurityGroups =  [Resource['FwbHASecurityGroup']]
    InsParm.SetSubnet(Resource['PublicSubnet'])
    InsParm.SetInterfaceSecGroups(SecurityGroups, InsParm.Subnets[count % InsParm.SubnetCount])

    UserData = '\n\"HaCloudInit\":\"enable\",'
    UserData += '\n\"HaPasswd\": \"' + Resource['FortiWebAdminPassword'] + '\",'
    UserData += '\n\"HaCfName\": \"' + Resource['FortiWebHACfName'] + '\",'
    UserData += '\n\"HaMode\": \"' +   Resource['FortiWebHAMode'] + '\",'
    UserData += '\n\"HaGroupName\":\"' +Resource['FortiWebHAGroupName'] + '\",'
    UserData += '\n\"HaGroupId\":\"' + Resource['FortiWebHAGroupID']+'\",'
    UserData += '\n\"HaOverride\":\"' +Resource['FortiWebHAOverride'] +'\",'
#if len(Resource['FortiWebFortiFlex'] < ins_count)
#	error handle
    UserData += '\n\"flex_token\":\"' +Resource['FortiWebFortiFlex'][count] +'\",'
    if Resource['FortiWebImageType'].find('BYOL') != -1:
        UserData += '\n\"HaBucket\":\"' +Resource['HAS3BucketName'] +'\",'
        UserData += '\n\"HaLicense\":\"' + lic_files[count] +'\",'

    if Resource['FortiWebHAMode'].find('active-passive') != -1:
        UserData += '\n\"HaEipIP\":\"' +Resource['FwbEIPIP'] +'\",'
        UserData += '\n\"HaEipId\":\"' +Resource['FwbEIPId'] +'\",'
    else:
        UserData += '\n\"HaTGHttp\":\"' +Resource['TargetGroupsHttp'] +'\",'
        UserData += '\n\"HaTGHttps\":\"' +Resource['TargetGroupsHttps'] +'\",'


    UserData += '\n\"HaInstanceCount\":\"' +Resource['FortiWebInstancesCount'] +'\"'
    UserData = '\nfwb_json_start {' + UserData + '\n}'

    InsParm.SetUserData(UserData)

    InsParm.SetIAM(Resource['IamFwbInstanceRoleArn'], Resource['IamInstanceProfileFwb'])

    return InsParm

def create_ec2_instance(event):
    licenses = []
    instances = []
    ec2_client = boto3.client('ec2')

    ins_count = int(event['ResourceProperties']['FortiWebInstancesCount'])

    if event['ResourceProperties']['FortiWebImageType'].find('BYOL') != -1:
        licenses = GetLicenseFileName(event['ResourceProperties']['HAS3BucketName'],
                                      event['ResourceProperties']['HAS3KeyPrefix'])
        if (len(licenses) < ins_count):
            print("Please upload enough license files into the %slicense directory" % (event['ResourceProperties']['HAS3KeyPrefix']))
            raise Exception('There is not engouh license files!')

    try:
        count = 0
        while count < ins_count:
            InsParm = InitInsParam(event, count, licenses)
            response = ec2_client.run_instances(ImageId =  InsParm.ImageId,
                                                InstanceType = InsParm.InsType,
                                                MaxCount=1,
                                                MinCount=1,
                                                NetworkInterfaces=InsParm.Interfaces,
                                                #Placement= {'AvailabilityZone': InsParm.Zone[count % InsParm.ZoneCount]},
                                                KeyName=InsParm.KeyName,
                                                TagSpecifications= InsParm.Tags,
                                                UserData= InsParm.UserData,
                                                IamInstanceProfile=InsParm.Iam)
            count += 1
            print(response['Instances'][0]['InstanceId'])
            instances.append(response['Instances'][0]['InstanceId'])
        print(instances)

    except ClientError as e:
        logging.error(e)
        return None
    return instances

def del_ec2_instance(event):

    client = boto3.client('ec2')

    if event['PhysicalResourceId'].find('i-') == -1:
        print("there is no instance need to terminate")
        return

    instanceIds = event['PhysicalResourceId'].split(',')
    if len(instanceIds) == 0:
        print("there is no instance need to terminate")
        return
    print(instanceIds)
    Resource = event['ResourceProperties']
    response = client.delete_tags(Resources = instanceIds,
                                Tags=[
                                {
                                     'Key': Resource['FortiWebHACfName'] + '-instance',
                                     'Value':Resource['FortiWebHACfName']
                                    }])
    print(response)
    response = client.terminate_instances(InstanceIds=instanceIds)

    print(response)
    client.get_waiter('instance_terminated').wait(InstanceIds=instanceIds)

def handler(event, context):
    print('Received event: %s' % json.dumps(event))
    responseData = {}
    instances ={}
    PhysicalId=''

    status = cfnresponse.SUCCESS
    try:
        if event['RequestType'] == 'Create':
            instances = create_ec2_instance(event)

            if instances is None:
                status = cfnresponse.FAILED
            else:
                PhysicalId = ','.join(instances)
        elif event['RequestType'] == 'Delete':
            del_ec2_instance(event)
    except Exception as e:
        status = cfnresponse.FAILED
        logging.error("Exception: %s" % e, exc_info=True)
    finally:
        cfnresponse.send(event, context, status,  {'InstancesId':instances}, PhysicalId)

