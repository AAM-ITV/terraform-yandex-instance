terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
     ansible = {
      source = "ansible/ansible"
      version = "1.3.0"
    }
 }
}
provider "yandex" {
  zone = "ru-central1-b"
}

resource "yandex_compute_disk" "boot-disk-1" {
  name     = "boot-disk-1"
  type     = "network-ssd"
  zone     = "ru-central1-b"
  size     = "20"
  image_id = "fd86ve4bb0dc66cjqpfu"
}

resource "yandex_compute_disk" "boot-disk-2" {
  name     = "boot-disk-2"
  type     = "network-ssd"
  zone     = "ru-central1-b"
  size     = "20"
  image_id = "fd86ve4bb0dc66cjqpfu"
}

resource "yandex_compute_instance" "vm-1" {
  name = "build-server"

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
    ssh-keys = "debian:${file("/root/.ssh/id_rsa.pub")}"
  }


}

resource "yandex_compute_instance" "vm-2" {
  name = "prod-server"

  resources {
    cores  = 4
    memory = 4
  }

  boot_disk {
    disk_id = yandex_compute_disk.boot-disk-2.id
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    nat       = true
  }

  metadata = {
    ssh-keys = "debian:${file("/root/.ssh/id_rsa.pub")}"
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

resource "local_file" "inventory" {
  content = <<-EOF
  [build]
  ${yandex_compute_instance.vm-1.network_interface.0.nat_ip_address} ansible_user=debian ansible_ssh_timeout=60 ansible_ssh_common_args='-o StrictHostKeyChecking=no' ansible_ssh_private_key_file=/root/.ssh/id_rsa
  [prod]
  ${yandex_compute_instance.vm-2.network_interface.0.nat_ip_address} ansible_user=debian ansible_ssh_timeout=60 ansible_ssh_common_args='-o StrictHostKeyChecking=no' ansible_ssh_private_key_file=/root/.ssh/id_rsa
  EOF
  filename = "${path.module}/inventory.ini"
}

resource "local_file" "playbook" {
  content = <<-EOF
- name: Build app for terraform
  hosts: build
  become: yes

  tasks:
  - name: Update APT cache
    apt:
      update_cache: yes

  - name: install docker
    apt:
      name: docker.io
      state: present

  - name: clone repo
    git:
      repo: https://github.com/AAM-ITV/App42PaaS-Java-MySQL.git
      dest: /tmp/App42PaaS-Java-MySQL
      force: yes # re-record repo if it exists

  - name: build and push project
    docker_image:
      build:
        path: /tmp/App42PaaS-Java-MySQL
      name: aamitv/app1-terraform
      tag: latest
      push: yes
      source: build



-  name: Build app for terraform
   hosts: prod
   become: yes

   tasks:

   - name: Update APT cache
     apt:
       update_cache: yes


   - name: install docker
     apt:
       name: docker.io
       state: present

   - name: Download the latest version of Docker Compose
     get_url:
       url: "https://github.com/docker/compose/releases/download/v2.19.0/docker-compose-{{ ansible_system | lower }}-{{ ansible_architecture }}"
       dest: /usr/bin/docker-compose
       mode: '0755'

   - name: clone repo
     git:
       repo: https://github.com/AAM-ITV/App42PaaS-Java-MySQL.git
       dest: /tmp/App42PaaS-Java-MySQL
       version: fixit
       force: yes # re-record repo if exist

   - name: Deploy Docker images
     command: docker-compose up -d
     args:
       chdir: /tmp/App42PaaS-Java-MySQL
EOF
  filename = "${path.module}/playbook.yml"
}

resource "null_resource" "ansible_playbook" {
  depends_on = [
    yandex_compute_instance.vm-1,
    yandex_compute_instance.vm-2
  ]

  provisioner "local-exec" {
    command = "ansible-playbook ${path.module}/playbook.yml -i ${path.module}/inventory.ini"
  }
}

output "internal_ip_address_vm_1" {
  value = yandex_compute_instance.vm-1.network_interface.0.ip_address
}

output "internal_ip_address_vm_2" {
  value = yandex_compute_instance.vm-2.network_interface.0.ip_address
}

output "external_ip_address_vm_1" {
  value = yandex_compute_instance.vm-1.network_interface.0.nat_ip_address
}

output "external_ip_address_vm_2" {
  value = yandex_compute_instance.vm-2.network_interface.0.nat_ip_address
}
