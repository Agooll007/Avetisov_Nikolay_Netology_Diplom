data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2204-lts"
}

# ----------------------------
# NETWORK
# ----------------------------
resource "yandex_vpc_network" "diploma_vpc" {
  name = var.vpc_name
}

resource "yandex_vpc_gateway" "nat_gateway" {
  name = "diploma-nat-gateway"

  shared_egress_gateway {}
}

resource "yandex_vpc_route_table" "private_route_table" {
  name       = "diploma-private-route"
  network_id = yandex_vpc_network.diploma_vpc.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat_gateway.id
  }
}

resource "yandex_vpc_subnet" "subnet_a" {
  name           = "${var.subnet_name}-a"
  zone           = var.zone_1
  network_id     = yandex_vpc_network.diploma_vpc.id
  v4_cidr_blocks = ["10.10.1.0/24"]
  route_table_id = yandex_vpc_route_table.private_route_table.id
}

resource "yandex_vpc_subnet" "subnet_b" {
  name           = "${var.subnet_name}-b"
  zone           = var.zone_2
  network_id     = yandex_vpc_network.diploma_vpc.id
  v4_cidr_blocks = ["10.10.2.0/24"]
  route_table_id = yandex_vpc_route_table.private_route_table.id
}

# ----------------------------
# SECURITY GROUPS
# ----------------------------
resource "yandex_vpc_security_group" "bastion_sg" {
  name       = "bastion-sg"
  network_id = yandex_vpc_network.diploma_vpc.id

  ingress {
    protocol       = "TCP"
    description    = "SSH from internet"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
  }

ingress {
  protocol       = "TCP"
  description    = "Zabbix agent access"
  v4_cidr_blocks = ["10.10.1.0/24"]
  port           = 10050
}

  egress {
    protocol       = "ANY"
    description    = "Allow all outbound"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}

resource "yandex_vpc_security_group" "alb_sg" {
  name       = "alb-sg"
  network_id = yandex_vpc_network.diploma_vpc.id

  ingress {
    protocol       = "TCP"
    description    = "HTTP from internet"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 80
  }

  ingress {
    protocol          = "TCP"
    description       = "Health checks from ALB"
    predefined_target = "loadbalancer_healthchecks"
    port              = 30080
  }

  egress {
    protocol       = "ANY"
    description    = "Allow all outbound"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 1
    to_port        = 65535
  }
}

resource "yandex_vpc_security_group" "web_sg" {
  name       = "web-sg"
  network_id = yandex_vpc_network.diploma_vpc.id

  ingress {
    protocol          = "TCP"
    description       = "HTTP from ALB"
    security_group_id = yandex_vpc_security_group.alb_sg.id
    port              = 80
  }

  ingress {
    protocol          = "TCP"
    description       = "Healthchecks from ALB"
    predefined_target = "loadbalancer_healthchecks"
    port              = 80
  }

  ingress {
    protocol          = "TCP"
    description       = "SSH from bastion SG"
    security_group_id = yandex_vpc_security_group.bastion_sg.id
    port              = 22
  }

ingress {
  protocol       = "TCP"
  description    = "Zabbix agent access"
  v4_cidr_blocks = ["10.10.1.0/24"]
  port           = 10050
}

  egress {
    protocol       = "ANY"
    description    = "Allow all outbound"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}

resource "yandex_vpc_security_group" "zabbix_sg" {
  name       = "zabbix-sg"
  network_id = yandex_vpc_network.diploma_vpc.id

  ingress {
    protocol       = "TCP"
    description    = "HTTP for Zabbix frontend"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 80
  }

  ingress {
    protocol          = "TCP"
    description       = "SSH from bastion SG"
    security_group_id = yandex_vpc_security_group.bastion_sg.id
    port              = 22
  }

  ingress {
    protocol       = "TCP"
    description    = "Zabbix server port from internal subnets"
    v4_cidr_blocks = ["10.10.1.0/24", "10.10.2.0/24"]
    port           = 10051
  }

  egress {
    protocol       = "ANY"
    description    = "Allow all outbound"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}

# ----------------------------
# BASTION
# ----------------------------
resource "yandex_compute_instance" "bastion" {
  name        = "bastion"
  hostname    = "bastion"
  zone        = var.zone_1
  platform_id = "standard-v3"
  allow_stopping_for_update = true

  scheduling_policy {
    preemptible = false
  }

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 10
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.subnet_a.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.bastion_sg.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${file("/home/avetisovnikolay/.ssh/bastion_id_rsa.pub")}"
  }
}

# ----------------------------
# WEB-1
# ----------------------------
resource "yandex_compute_instance" "web1" {
  name        = "web1"
  hostname    = "web1"
  zone        = var.zone_1
  platform_id = "standard-v3"
  allow_stopping_for_update = true


  scheduling_policy {
    preemptible = false
  }

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 10
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.subnet_a.id
    security_group_ids = [yandex_vpc_security_group.web_sg.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${file("/home/avetisovnikolay/.ssh/bastion_id_rsa.pub")}"
  }
}

# ----------------------------
# WEB-2
# ----------------------------
resource "yandex_compute_instance" "web2" {
  name        = "web2"
  hostname    = "web2"
  zone        = var.zone_2
  platform_id = "standard-v3"
  allow_stopping_for_update = true


  scheduling_policy {
    preemptible = false
  }

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 10
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.subnet_b.id
    security_group_ids = [yandex_vpc_security_group.web_sg.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${file("/home/avetisovnikolay/.ssh/bastion_id_rsa.pub")}"
  }
}

# ----------------------------
# TARGET GROUP
# ----------------------------
resource "yandex_alb_target_group" "web_tg" {
  name = "web-target-group"

  target {
    subnet_id  = yandex_vpc_subnet.subnet_a.id
    ip_address = yandex_compute_instance.web1.network_interface.0.ip_address
  }

  target {
    subnet_id  = yandex_vpc_subnet.subnet_b.id
    ip_address = yandex_compute_instance.web2.network_interface.0.ip_address
  }
}

# ----------------------------
# BACKEND GROUP
# ----------------------------
resource "yandex_alb_backend_group" "web_bg" {
  name = "web-backend-group"

  http_backend {
    name             = "web-backend"
    port             = 80
    target_group_ids = [yandex_alb_target_group.web_tg.id]

    healthcheck {
      timeout          = "3s"
      interval         = "5s"
      healthcheck_port = 80

      http_healthcheck {
        path = "/"
      }
    }
  }
}

# ----------------------------
# HTTP ROUTER
# ----------------------------
resource "yandex_alb_http_router" "web_router" {
  name = "web-router"
}

# ----------------------------
# VIRTUAL HOST
# ----------------------------
resource "yandex_alb_virtual_host" "web_vhost" {
  name           = "web-virtual-host"
  http_router_id = yandex_alb_http_router.web_router.id
  authority      = ["*"]

  route {
    name = "root-route"

    http_route {
      http_route_action {
        backend_group_id = yandex_alb_backend_group.web_bg.id
      }
    }
  }
}

# ----------------------------
# APPLICATION LOAD BALANCER
# ----------------------------
resource "yandex_alb_load_balancer" "web_alb" {
  name               = "web-alb"
  network_id         = yandex_vpc_network.diploma_vpc.id
  security_group_ids = [yandex_vpc_security_group.alb_sg.id]

  allocation_policy {
    location {
      zone_id   = var.zone_1
      subnet_id = yandex_vpc_subnet.subnet_a.id
    }

    location {
      zone_id   = var.zone_2
      subnet_id = yandex_vpc_subnet.subnet_b.id
    }
  }

  listener {
    name = "http-listener"

    endpoint {
      address {
        external_ipv4_address {}
      }
      ports = [80]
    }

    http {
      handler {
        http_router_id = yandex_alb_http_router.web_router.id
      }
    }
  }
}

# ----------------------------
# ZABBIX SERVER
# ----------------------------
resource "yandex_compute_instance" "zabbix" {
  name        = "zabbix"
  hostname    = "zabbix"
  zone        = var.zone_1
  platform_id = "standard-v3"
  allow_stopping_for_update = true


  scheduling_policy {
    preemptible = false
  }

  resources {
    cores         = 2
    memory        = 4
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 20
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.subnet_a.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.zabbix_sg.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${file("/home/avetisovnikolay/.ssh/bastion_id_rsa.pub")}"
  }
}

# ----------------------------
# ELASTICSEARCH SECURITY GROUP
# ----------------------------
resource "yandex_vpc_security_group" "elasticsearch_sg" {
  name       = "elasticsearch-sg"
  network_id = yandex_vpc_network.diploma_vpc.id

  ingress {
    protocol          = "TCP"
    description       = "SSH from bastion SG"
    security_group_id = yandex_vpc_security_group.bastion_sg.id
    port              = 22
  }

  ingress {
    protocol       = "TCP"
    description    = "Elasticsearch from internal subnets"
    v4_cidr_blocks = ["10.10.1.0/24", "10.10.2.0/24"]
    port           = 9200
  }

  egress {
    protocol       = "ANY"
    description    = "Allow all outbound"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}

# ----------------------------
# KIBANA SECURITY GROUP
# ----------------------------
resource "yandex_vpc_security_group" "kibana_sg" {
  name       = "kibana-sg"
  network_id = yandex_vpc_network.diploma_vpc.id

  ingress {
    protocol       = "TCP"
    description    = "Kibana web access"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 5601
  }

  ingress {
    protocol          = "TCP"
    description       = "SSH from bastion SG"
    security_group_id = yandex_vpc_security_group.bastion_sg.id
    port              = 22
  }

  egress {
    protocol       = "ANY"
    description    = "Allow all outbound"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}

# ----------------------------
# ELASTICSEARCH SERVER
# ----------------------------
resource "yandex_compute_instance" "elasticsearch" {
  name        = "elasticsearch"
  hostname    = "elasticsearch"
  zone        = var.zone_1
  platform_id = "standard-v3"
  allow_stopping_for_update = true


  scheduling_policy {
    preemptible = false
  }

  resources {
    cores         = 2
    memory        = 4
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 20
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.subnet_a.id
    security_group_ids = [yandex_vpc_security_group.elasticsearch_sg.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${file("/home/avetisovnikolay/.ssh/bastion_id_rsa.pub")}"
  }
}

# ----------------------------
# KIBANA SERVER
# ----------------------------
resource "yandex_compute_instance" "kibana" {
  name        = "kibana"
  hostname    = "kibana"
  zone        = var.zone_1
  platform_id = "standard-v3"
  allow_stopping_for_update = true


  scheduling_policy {
    preemptible = false
  }

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 20
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.subnet_a.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.kibana_sg.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${file("/home/avetisovnikolay/.ssh/bastion_id_rsa.pub")}"
  }
}

# ----------------------------
# SNAPSHOT SCHEDULE
# ----------------------------
resource "yandex_compute_snapshot_schedule" "daily_snapshots" {
  name        = "daily-vm-snapshots"
  description = "Daily snapshots for all diploma VMs"

  schedule_policy {
    expression = "0 2 * * *"
  }

  retention_period = "168h"

  snapshot_spec {
    description = "Daily snapshot created by Terraform"
    labels = {
      project = "netology-diploma"
      type    = "daily-backup"
    }
  }

  disk_ids = [
    yandex_compute_instance.bastion.boot_disk[0].disk_id,
    yandex_compute_instance.web1.boot_disk[0].disk_id,
    yandex_compute_instance.web2.boot_disk[0].disk_id,
    yandex_compute_instance.zabbix.boot_disk[0].disk_id,
    yandex_compute_instance.elasticsearch.boot_disk[0].disk_id,
    yandex_compute_instance.kibana.boot_disk[0].disk_id
  ]
}
