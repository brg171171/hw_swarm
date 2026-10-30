terraform {
  required_version = ">= 1.5.0"

  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}

provider "yandex" {
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.zone
}

locals {
  nodes = {
    swarm-manager  = "10.60.10.10"
    swarm-worker-1 = "10.60.20.11"
    swarm-worker-2 = "10.60.30.12"
  }
}

data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2404-lts"
}

resource "yandex_vpc_network" "swarm" {
  name = "swarm-net"
}

resource "yandex_vpc_subnet" "swarm" {
  name           = "swarm-subnet"
  zone           = var.zone
  network_id     = yandex_vpc_network.swarm.id
  v4_cidr_blocks = ["10.60.10.0/24"]
}

resource "yandex_vpc_subnet" "workers" {
  name           = "swarm-workers-subnet-d"
  zone           = "ru-central1-d"
  network_id     = yandex_vpc_network.swarm.id
  v4_cidr_blocks = ["10.60.20.0/24"]
}

resource "yandex_vpc_subnet" "worker2" {
  name           = "swarm-worker2-subnet-e"
  zone           = "ru-central1-e"
  network_id     = yandex_vpc_network.swarm.id
  v4_cidr_blocks = ["10.60.30.0/24"]
}

resource "yandex_vpc_security_group" "swarm" {
  name       = "swarm-sg"
  network_id = yandex_vpc_network.swarm.id

  ingress {
    description    = "SSH from administrator"
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = [var.admin_cidr]
  }

  ingress {
    description = "Swarm management"
    protocol    = "TCP"
    port        = 2377
    v4_cidr_blocks = [
      "10.60.10.0/24",
      "10.60.20.0/24",
      "10.60.30.0/24"
    ]
  }

  ingress {
    description = "Swarm discovery TCP"
    protocol    = "TCP"
    port        = 7946
    v4_cidr_blocks = [
      "10.60.10.0/24",
      "10.60.20.0/24",
      "10.60.30.0/24"
    ]
  }

  ingress {
    description = "Swarm discovery UDP"
    protocol    = "UDP"
    port        = 7946
    v4_cidr_blocks = [
      "10.60.10.0/24",
      "10.60.20.0/24",
      "10.60.30.0/24"
    ]
  }

  ingress {
    description = "Swarm overlay traffic"
    protocol    = "UDP"
    port        = 4789
    v4_cidr_blocks = [
      "10.60.10.0/24",
      "10.60.20.0/24",
      "10.60.30.0/24"
    ]
  }

  ingress {
    description    = "SSH from Swarm manager"
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["10.60.10.10/32"]
  }

  egress {
    description    = "Outgoing traffic"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_compute_instance" "node" {
  for_each = local.nodes

  name     = each.key
  hostname = each.key
  zone = {
    "swarm-manager"  = var.zone
    "swarm-worker-1" = "ru-central1-d"
    "swarm-worker-2" = "ru-central1-e"
  }[each.key]
  platform_id = "standard-v3"

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      type     = "network-hdd"
      size     = 15
    }
  }

  network_interface {
    subnet_id = {
      "swarm-manager"  = yandex_vpc_subnet.swarm.id
      "swarm-worker-1" = yandex_vpc_subnet.workers.id
      "swarm-worker-2" = yandex_vpc_subnet.worker2.id
    }[each.key]

    ip_address         = each.value
    nat                = true
    security_group_ids = [yandex_vpc_security_group.swarm.id]
  }

  metadata = {
    user-data = "#cloud-config\n${yamlencode({
      users = [
        {
          name   = "ubuntu"
          groups = ["sudo"]
          shell  = "/bin/bash"
          sudo   = "ALL=(ALL) NOPASSWD:ALL"
          "ssh-authorized-keys" = [
            trimspace(file(pathexpand(var.ssh_public_key_path)))
          ]
        }
      ]
      ssh_pwauth = false
    })}"
  }
}
