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
  default = "https://www.googleapis.com/compute/v1/projects/fortigcp-project-001/global/images/fwb-720-payg-21122022-001-w-license"
}
# GCP region
variable "region" {
  type    = string
  default = "us-central1" #Default Region
}
# GCP zone
variable "zone_active" {
  type    = string
  default = "us-central1-a" #Default Zone
}
# GCP zone
variable "zone_passive" {
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
# license file for active
variable "licenseFile" {
  type    = string
  default = "license1.lic"
}
# license file for passive
variable "licenseFile2" {
  type    = string
  default = "license2.lic"
}

variable "mgmt_mask" {
  type    = string
  default = "255.255.255.0"
}

# active interface ip assignments
# active ext
variable "active_port1_ip" {
  type    = string
  default = "172.16.0.2"
}
variable "active_port1_mask" {
  type    = string
  default = "32"
}
# active int
variable "active_port2_ip" {
  type    = string
  default = "172.16.1.2"
}
variable "active_port2_mask" {
  type    = string
  default = "32"
}
# active sync
variable "active_port3_ip" {
  type    = string
  default = "172.16.2.2"
}
variable "active_port3_mask" {
  type    = string
  default = "24"
}

# passive sync interface ip assignments
#passive ext
variable "passive_port1_ip" {
  type    = string
  default = "172.16.0.3"
}
variable "passive_port1_mask" {
  type    = string
  default = "32"
}

# passive int
variable "passive_port2_ip" {
  type    = string
  default = "172.16.1.3"
}
variable "passive_port2_mask" {
  type    = string
  default = "32"
}


# passive sync
variable "passive_port3_ip" {
  type    = string
  default = "172.16.2.3"
}
variable "passive_port3_mask" {
  type    = string
  default = "24"
}
