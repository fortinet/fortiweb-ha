# GCP project name
variable "project" {
  type    = string
  default = ""
}
variable "credentials_file_path" {
    type    = string
    default = ""
}
variable "service_account" {
    type    = string
    default = ""
}
# FortiWeb Image name
variable "image" {
  type    = string
  default = "https://www.googleapis.com/compute/v1/projects/fortigcp-project-001/global/images/fwb-760-payg-07092024-001-w-license"
#  default = "https://www.googleapis.com/compute/v1/projects/fortigcp-project-001/global/images/fwb-760-byol-07092024-001-w-license"
}
# GCP region
variable "region" {
  type    = string
  default = "us-central1" #Default Region
}
# GCP zone
variable "zone_active1" {
  type    = string
  default = "us-central1-a" #Default Zone
}
variable "zone_active2" {
  type    = string
  default = "us-central1-b" #Default Zone
}
# GCP instance machine type
variable "machine" {
  type    = string
  default = "n1-standard-4"
}
# VPC CIDR
variable "vpc_cidr" {
  type    = string
  default = "172.16.0.0/16"
}
# Public Subnet CIDR
variable "public_subnet" {
  type    = string
  default = "172.16.0.0/24"
}
# Private Subnet CIDR
variable "protected_subnet" {
  type    = string
  default = "172.16.1.0/24"
}
# HA Subnet CIDR
variable "ha_subnet" {
  type    = string
  default = "172.16.2.0/24"
}
# license file for active1
variable "licenseFile" {
  type    = string
  default = "license1.lic"
}
# license file for active2
variable "licenseFile2" {
  type    = string
  default = "license2.lic"
}

# flex token for active
variable "flextoken" {
  type    = string
  default = ""
}
# flex token for active2
variable "flextoken2" {
  type    = string
  default = ""
}

variable "mgmt_mask" {
  type    = string
  default = "255.255.255.0"
}

# active1 interface ip assignments
# active1 ext
variable "active1_port1_ip" {
  type    = string
  default = "172.16.0.2"
}
variable "active1_port1_mask" {
  type    = string
  default = "32"
}
# active1 int
variable "active1_port2_ip" {
  type    = string
  default = "172.16.1.2"
}
variable "active1_port2_mask" {
  type    = string
  default = "32"
}
# active1 sync
variable "active1_port3_ip" {
  type    = string
  default = "172.16.2.2"
}
variable "active1_port3_mask" {
  type    = string
  default = "24"
}

# active2 sync interface ip assignments
#active2 ext
variable "active2_port1_ip" {
  type    = string
  default = "172.16.0.3"
}
variable "active2_port1_mask" {
  type    = string
  default = "32"
}

# active2 int
variable "active2_port2_ip" {
  type    = string
  default = "172.16.1.3"
}
variable "active2_port2_mask" {
  type    = string
  default = "32"
}


# active2 sync
variable "active2_port3_ip" {
  type    = string
  default = "172.16.2.3"
}
variable "active2_port3_mask" {
  type    = string
  default = "24"
}
