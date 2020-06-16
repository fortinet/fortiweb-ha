# FortiWeb HA

This project contains the code and templates for the **Amazon AWS** and **Microsoft Azure** Fortiweb HA deployments.

This project is organized in separate node modules:
* [fortiweb-ha/azure](azure) contains a template for the deployment of Fortiweb HA on the **Microsoft Azure** platform API.
 * [fortiweb-ha/aws](aws) contains templates and lambda function for the deployment of Fortiweb HA on the **AWS SDK** platform API.

The project also contains a deployment script that can generate packages for each cloud service's *serverless* implementation.

## Supported Platforms
This project supports Fortiweb HA for the cloud platforms listed below.
  * Amazon AWS
  * Microsoft Azure

## Deployment Packages
To generate local deployment packages:

  1. Clone this project.
  2. Run `./script/make_dist.sh` at the project root directory.

Deployment packages as well as source code will be available in the **dist** directory.

| Package Name | Description |
| ------ | ------ |
| fortiweb-ha-aws-cloudformation.zip | Cloud Formation template. Use this to deploy the solution on the AWS platform.|
| fortiweb-ha-azure-quickstart.zip | Azure template. Use this to deploy the solution on the Azure platform.|

Installation Guides are available from the Fortinet Document Library:
  * [ FortiWeb /Use Case: High Availability for FortiWeb on AWS](https://docs.fortinet.com/vm/aws/fortiweb/6.3/use-case-high-availability-for-fortiweb-on-aws/6.3.4/556435/overview)
  * [ FortiWeb /Use Case: High Availability for FortiWeb on Azure](https://docs.fortinet.com/vm/azure/fortiweb/6.3/use-case-high-availability-for-fortiweb-on-azure/6.3.4/277766/overview)

# Support
Fortinet-provided scripts in this and other GitHub projects do not fall under the regular Fortinet technical support scope and are not supported by FortiCare Support Services.
For direct issues, please refer to the [Issues](https://github.com/fortinet/fortiweb-ha/issues) tab of this GitHub project.
For other questions related to this project, contact [github@fortinet.com](mailto:github@fortinet.com).

## License
[License](https://github.com/fortinet/fortiweb-ha/blob/master/LICENSE) © Fortinet Technologies. All rights reserved.
