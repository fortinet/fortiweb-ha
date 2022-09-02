### Forwarding Rule ###
resource "google_compute_forwarding_rule" "default" {
  name   = "external-lb-${random_string.random_name_post.result}"
  region = var.region

  load_balancing_scheme = "EXTERNAL"
  target                = google_compute_target_pool.default.self_link
}

### Target Pools ###
resource "google_compute_target_pool" "default" {
  name             = "fwb-instancepool-${random_string.random_name_post.result}"
  region           = var.region
  session_affinity = "CLIENT_IP"

  instances = [
     "${var.zone_active1}/fwb-${random_string.random_name_post.result}",
     "${var.zone_active2}/fwb-2-${random_string.random_name_post.result}"
  ]

  health_checks = [
    "${google_compute_http_health_check.default.name}",
  ]
}

### Health Check ###
resource "google_compute_http_health_check" "default" {
  name                = "health-check-backend-${random_string.random_name_post.result}"
  check_interval_sec  = 3
  timeout_sec         = 2
  unhealthy_threshold = 3
  port                = "8008"
}


