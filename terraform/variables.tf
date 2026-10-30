variable "cloud_id" {
  type = string
}

variable "folder_id" {
  type = string
}

variable "zone" {
  type    = string
  default = "ru-central1-a"
}

variable "admin_cidr" {
  description = "Публичный адрес управляющей машины в формате x.x.x.x/32"
  type        = string
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/netology_swarm.pub"
}

variable "ssh_private_key_path" {
  type    = string
  default = "~/.ssh/netology_swarm"
}
