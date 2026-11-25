terraform {
  required_version = ">= 1.5"

  required_providers {
    dns = {
      source  = "hashicorp/dns"
      version = "~> 3.4"
    }
  }
}

variable "dns_server" {
  description = "IP adresa naseg BIND servera"
  type        = string
  default     = "192.168.122.158"
}

variable "tsig_key_path" {
  description = "Lokalna putanja do TSIG kljuca"
  type        = string
  default     = "~/.config/ruo/ruo-tf.key"
}

locals {
  tsig_secret = regex(
    "secret\\s+\"([^\"]+)\"",
    sensitive(file(pathexpand(var.tsig_key_path)))
  )[0]

  services = {
    web = var.dns_server
    api = "172.28.20.20"
    db  = "172.28.30.20"
  }
}

provider "dns" {
  update {
    server        = var.dns_server
    key_name      = "ruo-tf."
    key_algorithm = "hmac-sha256"
    key_secret    = local.tsig_secret
  }
}

resource "dns_a_record_set" "services" {
  for_each = local.services

  zone      = "ruo.test."
  name      = each.key
  addresses = [each.value]
  ttl       = 300
}

output "service_names" {
  value = [
    for name in keys(local.services) : "${name}.ruo.test"
  ]
}