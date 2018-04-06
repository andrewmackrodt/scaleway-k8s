variable "region" {
  default = "par1"
}

variable "architecture" {
  default = "x86_64"
}

variable "image" {
  default = "Ubuntu Xenial"
}

variable "master_instance_type" {
  default = "VC1S"
}

variable "master_instance_count" {
  default = 3
}

variable "proxy_instance_type" {
  default = "VC1S"
}

variable "worker_instance_type" {
  default = "VC1M"
}

variable "worker_volume_size" {
  default = 100
}

variable "worker_instance_count" {
  default = 3
}
