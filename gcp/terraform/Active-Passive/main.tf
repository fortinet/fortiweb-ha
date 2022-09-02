## GCP terraform for HA setup
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
  zone         = var.zone_active
  
  #access_token = var.token
}
provider "google-beta" {
  #version     = "3.49.0"
  credentials = file(var.credentials_file_path)
  project      = var.project
  region       = var.region
  zone         = var.zone_passive
#  access_token = var.token
}

# Randomize string to avoid duplication
resource "random_string" "random_name_post" {
  length           = 3
  special          = true
  override_special = ""
  min_lower        = 3
}

# Create log disk for active
resource "google_compute_disk" "logdisk" {
  name = "log-disk-${random_string.random_name_post.result}"
  size = 30
  type = "pd-standard"
  zone = var.zone_active
}

# Create log disk for passive
resource "google_compute_disk" "logdisk2" {
  name = "log-disk2-${random_string.random_name_post.result}"
  size = 30
  type = "pd-standard"
  zone = var.zone_passive
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
  next_hop_ip = var.active_port2_ip
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

# active userdata pre-configuration
data "template_file" "setup-active" {
  template = file("${path.module}/active")
  vars = {
    active_port3_ip   = var.active_port3_ip
    passive_hb_ip     = var.passive_port3_ip // passive hb ip
    lb_name           =  "${google_compute_target_pool.default.name}"
  }
}

# passive userdata pre-configuration
data "template_file" "setup-passive" {
  template = file("${path.module}/passive")
  vars = {
    passive_port3_ip   = var.passive_port3_ip
    active_hb_ip       = var.active_port3_ip // active hb ip
    lb_name           =  "${google_compute_target_pool.default.name}"
  }
}

# Create static active instance management ip
resource "google_compute_address" "static" {
  name = "activemgmt-ip-${random_string.random_name_post.result}"
}

# Create static passive instance management ip
resource "google_compute_address" "static2" {
  name = "passivemgmt-ip-${random_string.random_name_post.result}"
}

# Create FWBVM compute active instance
resource "google_compute_instance" "default" {
  name           = "fwb-${random_string.random_name_post.result}"
  machine_type   = var.machine
  zone           = var.zone_active
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
    network_ip = var.active_port1_ip
    access_config {
      nat_ip = google_compute_address.static.address
    }
  }
  network_interface {
    subnetwork = google_compute_subnetwork.private_subnet.name
    network_ip = var.active_port2_ip
  }

  network_interface {
    subnetwork = google_compute_subnetwork.ha_subnet.name
    network_ip = var.active_port3_ip
  }

  metadata = {
    user-data = "${data.template_file.setup-active.rendered}"
    license   = fileexists("${path.module}/${var.licenseFile}") ? "${file(var.licenseFile)}" : null
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

# Create FWBVM compute passive instance
resource "google_compute_instance" "default2" {
  name           = "fwb-2-${random_string.random_name_post.result}"
  machine_type   = var.machine
  zone           = var.zone_passive
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
    network_ip = var.passive_port1_ip
    access_config {
      nat_ip = google_compute_address.static2.address
    }
  }
  network_interface {
    subnetwork = google_compute_subnetwork.private_subnet.name
    network_ip = var.passive_port2_ip
  }
  network_interface {
    subnetwork = google_compute_subnetwork.ha_subnet.name
    network_ip = var.passive_port3_ip
  }
  metadata = {
    user-data = "${data.template_file.setup-passive.rendered}"
    license   = fileexists("${path.module}/${var.licenseFile2}") ? "${file(var.licenseFile2)}" : null
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
output "FortiWeb-HA-Primary-MGMT-IP" {
  value = google_compute_instance.default.network_interface.0.access_config.0.nat_ip
}
output "FortiWeb-HA-Secondary-MGMT-IP" {
  value = google_compute_instance.default2.network_interface.0.access_config.0.nat_ip
}

output "FortiWeb-Username" {
  value = "admin"
}
output "FortiWeb-Password" {
  value = google_compute_instance.default.instance_id
}

