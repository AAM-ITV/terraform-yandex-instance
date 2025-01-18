terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  token     = "y0_AgAAAAAGKyuaAATuwQAAAAEL6APzAABFyWvjhZVO46RIP6-7enyK-JzXvg"
  cloud_id  = "b1gpl53sdobvpahkcboc"
  folder_id = "b1ge0llpg1gnn3hpv1n4"
  zone      = "ru-central1-b"
}

resource "yandex_compute_disk" "boot-disk-1" {
  name     = "boot-disk-1"
  type     = "network-ssd"
  zone     = "ru-central1-b"
  size     = "20"
  image_id = "fd866kfu2hbk46j2e21q"
}

resource "yandex_compute_instance" "vm-1" {
  name = "prod-server"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    disk_id = yandex_compute_disk.boot-disk-1.id
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    nat       = true
  }

  metadata = {
    user-data = "${file("/var/lib/jenkins/workspace/deploy-app/cloud-config.txt")}"
  }
}

resource "yandex_vpc_network" "network-1" {
  name = "network1"
}

resource "yandex_vpc_subnet" "subnet-1" {
  name           = "subnet1"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.network-1.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

output "internal_ip_address_prod-stand" {
  value = yandex_compute_instance.vm-1.network_interface.0.ip_address
}


output "external_ip_address_prod-stand" {
  value = yandex_compute_instance.vm-1.network_interface.0.nat_ip_address
}
