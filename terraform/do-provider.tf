variable "do_token" {
}

variable "pvt_key" {
}

variable "ssh_fingerprint" {
  default = ""
}

variable "server_instance_count" {
  default = "3"
}

variable "client_instance_count" {
  default = "3"
}

variable "do_snapshot_id" {
}

variable "do_region" {
  default = "nyc1"
}

variable "do_size" {
  default = "s-1vcpu-2gb"
}

variable "do_private_networking" {
  default = true
}

provider "digitalocean" {
  token = var.do_token
}

data "digitalocean_ssh_key" "do" {
  name = "do"
}