terraform {
  required_version = ">= 1.5"

  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.8.3"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

variable "vm_name" {
  description = "Naziv virtuelne masine"
  type        = string
  default     = "ruo-vm"
}

variable "memory_mb" {
  description = "RAM memorija u MiB"
  type        = number
  default     = 4096
}

variable "vcpu_count" {
  description = "Broj virtuelnih procesora"
  type        = number
  default     = 2
}

variable "disk_gb" {
  description = "Velicina diska u GiB"
  type        = number
  default     = 25
}

variable "ssh_public_key_path" {
  description = "Putanja do javnog SSH kljuca"
  type        = string
  default     = "~/.ssh/ruo_projekat.pub"
}

variable "ubuntu_image_url" {
  description = "Ubuntu 24.04 cloud slika"
  type        = string
  default     = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
}

resource "libvirt_volume" "base" {
  name   = "${var.vm_name}-base.qcow2"
  pool   = "default"
  format = "qcow2"
  source = var.ubuntu_image_url
}

resource "libvirt_volume" "disk" {
  name           = "${var.vm_name}-disk.qcow2"
  pool           = "default"
  base_volume_id = libvirt_volume.base.id
  size           = var.disk_gb * 1024 * 1024 * 1024
}

resource "libvirt_cloudinit_disk" "init" {
  name = "${var.vm_name}-init.iso"
  pool = "default"

  user_data = templatefile(
    "${path.module}/../../cloud-init/user-data.tftpl",
    {
      ssh_key = trimspace(
        file(pathexpand(var.ssh_public_key_path))
      )
    }
  )
}

resource "libvirt_domain" "vm" {
  name   = var.vm_name
  type   = "qemu"
  memory = var.memory_mb
  vcpu   = var.vcpu_count

  cloudinit = libvirt_cloudinit_disk.init.id

  disk {
    volume_id = libvirt_volume.disk.id
  }

  network_interface {
    network_name   = "default"
    wait_for_lease = true
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }
}

output "vm_name" {
  description = "Naziv kreirane masine"
  value       = libvirt_domain.vm.name
}

output "vm_addresses" {
  description = "IP adrese virtuelne masine"
  value       = libvirt_domain.vm.network_interface[0].addresses
}