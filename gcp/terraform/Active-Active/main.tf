### GCP terraform for HA setup
terraform {
  required_version = ">=0.12.0"
  required_providers {
    google      = ">=2.11.0"
    google-beta = ">=2.13"
  }
}
provider "google" {
  #version     = "3.49.0"
  credentials = file(var.credentials_file_path)
  project      = var.project
  region       = var.region
  zone         = var.zone_active1
  
  #access_token = var.token
}
provider "google-beta" {
  #version     = "3.49.0"
  credentials = file(var.credentials_file_path)
  project      = var.project
  region       = var.region
  zone         = var.zone_active2
#  access_token = var.token
}

# Randomize string to avoid duplication
resource "random_string" "random_name_post" {
  length           = 3
  special          = true
  override_special = ""
  min_lower        = 3
}

# Create log disk for active1
resource "google_compute_disk" "logdisk" {
  name = "log-disk-${random_string.random_name_post.result}"
  size = 30
  type = "pd-standard"
  zone = var.zone_active1
}

# Create log disk for active2
resource "google_compute_disk" "logdisk2" {
  name = "log-disk2-${random_string.random_name_post.result}"
  size = 30
  type = "pd-standard"
  zone = var.zone_active2
}

########### Network Related
### VPC ###
resource "google_compute_network" "vpc_network" {
  name                    = "vpc-${random_string.random_name_post.result}"
  auto_create_subnetworks = false
}

resource "google_compute_network" "vpc_network2" {
  name                    = "vpc2-${random_string.random_name_post.result}"
  auto_create_subnetworks = false
}

resource "google_compute_network" "vpc_network3" {
  name                    = "vpc3-${random_string.random_name_post.result}"
  auto_create_subnetworks = false
}


### Public Subnet ###
resource "google_compute_subnetwork" "public_subnet" {
  name                     = "public-subnet-${random_string.random_name_post.result}"
  region                   = var.region
  network                  = google_compute_network.vpc_network.name
  ip_cidr_range            = var.public_subnet
  private_ip_google_access = true
}
### Private Subnet ###
resource "google_compute_subnetwork" "private_subnet" {
  name          = "private-subnet-${random_string.random_name_post.result}"
  region        = var.region
  network       = google_compute_network.vpc_network2.name
  ip_cidr_range = var.protected_subnet
}
### HA Sync Subnet ###
resource "google_compute_subnetwork" "ha_subnet" {
  name          = "sync-subnet-${random_string.random_name_post.result}"
  region        = var.region
  network       = google_compute_network.vpc_network3.name
  ip_cidr_range = var.ha_subnet
}


resource "google_compute_route" "internal" {
  name        = "internal-route-${random_string.random_name_post.result}"
  dest_range  = "0.0.0.0/0"
  network     = google_compute_network.vpc_network2.name
  next_hop_ip = var.active1_port2_ip
  priority    = 100
  depends_on  = [google_compute_subnetwork.private_subnet]
}


# Firewall Rule External
resource "google_compute_firewall" "allow-fwb" {
  name    = "allow-fwb-${random_string.random_name_post.result}"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443", "8443", "8080"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["allow-fwb"]
}

# Firewall Rule Internal
resource "google_compute_firewall" "allow-internal" {
  name    = "allow-internal-${random_string.random_name_post.result}"
  network = google_compute_network.vpc_network2.name

  allow {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["allow-internal"]
}

# Firewall Rule HA SYNC
resource "google_compute_firewall" "allow-sync" {
  name    = "allow-sync-${random_string.random_name_post.result}"
  network = google_compute_network.vpc_network3.name

  allow {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["allow-sync"]
}

########### Instance Related

# active1 userdata pre-configuration
data "template_file" "setup-active1" {
  template = file("${path.module}/active1")
  vars = {
    active1_port3_ip   = var.active1_port3_ip
    active2_hb_ip     = var.active2_port3_ip // active2 hb ip
    lb_name           =  "${google_compute_target_pool.default.name}"
  }
}

# active2 userdata pre-configuration
data "template_file" "setup-active2" {
  template = file("${path.module}/active2")
  vars = {
    active2_port3_ip   = var.active2_port3_ip
    active1_hb_ip       = var.active1_port3_ip // active1 hb ip
    lb_name           =  "${google_compute_target_pool.default.name}"
  }
}

# Create static active1 instance management ip
resource "google_compute_address" "static" {
  name = "active1mgmt-ip-${random_string.random_name_post.result}"
}

# Create static active2 instance management ip
resource "google_compute_address" "static2" {
  name = "active2mgmt-ip-${random_string.random_name_post.result}"
}

# Create FWBVM compute active1 instance
resource "google_compute_instance" "default" {
  name           = "fwb-${random_string.random_name_post.result}"
  machine_type   = var.machine
  zone           = var.zone_active1
  can_ip_forward = "true"

  tags = ["allow-fwb", "allow-internal", "allow-sync", "allow-mgmt"]

  boot_disk {
    initialize_params {
      image = var.image
    }
  }
  attached_disk {
    source = google_compute_disk.logdisk.name
  }
  network_interface {
    subnetwork = google_compute_subnetwork.public_subnet.name
    network_ip = var.active1_port1_ip
    access_config {
      nat_ip = google_compute_address.static.address
    }
  }
  network_interface {
    subnetwork = google_compute_subnetwork.private_subnet.name
    network_ip = var.active1_port2_ip
  }

  network_interface {
    subnetwork = google_compute_subnetwork.ha_subnet.name
    network_ip = var.active1_port3_ip
  }

  metadata = {
    user-data = "${data.template_file.setup-active1.rendered}"
    license   = fileexists("${path.module}/${var.licenseFile}") ? "${file(var.licenseFile)}" : null
    flex_token = var.flextoken == "" ? null : var.flextoken
  }
  service_account {
    email  = "${var.service_account}"      
    scopes = ["userinfo-email", "compute-rw", "storage-ro", "cloud-platform"]
  }
  scheduling {
    preemptible       = true
    automatic_restart = false
  }
}

# Create FWBVM compute active2 instance
resource "google_compute_instance" "default2" {
  depends_on = [google_compute_instance.default]
  name           = "fwb-2-${random_string.random_name_post.result}"
  machine_type   = var.machine
  zone           = var.zone_active2
  can_ip_forward = "true"

  tags = ["allow-fwb", "allow-internal", "allow-sync", "allow-mgmt"]

  boot_disk {
    initialize_params {
      image = var.image
    }
  }
  attached_disk {
    source = google_compute_disk.logdisk2.name
  }
  network_interface {
    subnetwork = google_compute_subnetwork.public_subnet.name
    network_ip = var.active2_port1_ip
    access_config {
      nat_ip = google_compute_address.static2.address
    }
  }
  network_interface {
    subnetwork = google_compute_subnetwork.private_subnet.name
    network_ip = var.active2_port2_ip
  }
  network_interface {
    subnetwork = google_compute_subnetwork.ha_subnet.name
    network_ip = var.active2_port3_ip
  }
  metadata = {
    user-data = "${data.template_file.setup-active2.rendered}"
    license   = fileexists("${path.module}/${var.licenseFile2}") ? "${file(var.licenseFile2)}" : null
    flex_token = var.flextoken2 == "" ? null : var.flextoken2
  }
  service_account {
    email  = "${var.service_account}"
    scopes = ["userinfo-email", "compute-rw", "storage-ro", "cloud-platform"]
  }
  scheduling {
    preemptible       = true
    automatic_restart = false
  }
}





# Output
output "Load-Balancer-IP" {
  value = google_compute_forwarding_rule.default.ip_address
}
output "FortiWeb-HA-AA1-MGMT-IP" {
  value = google_compute_instance.default.network_interface.0.access_config.0.nat_ip
}
output "FortiWeb-HA-AA2-MGMT-IP" {
  value = google_compute_instance.default2.network_interface.0.access_config.0.nat_ip
}

output "FortiWeb-Username" {
  value = "admin"
}
output "FortiWeb-Password" {
  value = google_compute_instance.default.instance_id
}

