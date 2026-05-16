variable "hcloud_token" {
  description = "Hetzner Cloud API token (sensitive). Provide via TF_VAR_hcloud_token or terraform.tfvars."
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "Public SSH key (OpenSSH format) injected via cloud-init into both VMs."
  type        = string
}

variable "location" {
  description = "Hetzner location code (nbg1/fsn1/hel1/ash/hil)."
  type        = string
  default     = "nbg1"
}

variable "server_type" {
  description = "Hetzner server type. cx22 = 2 vCPU / 4 GB / 40 GB SSD."
  type        = string
  default     = "cx22"
}

variable "image" {
  description = "OS image slug."
  type        = string
  default     = "ubuntu-24.04"
}

variable "private_cidr" {
  description = "Private subnet CIDR for the worker+db network."
  type        = string
  default     = "10.0.1.0/24"
}

variable "worker_private_ip" {
  description = "Static private IP of the worker server."
  type        = string
  default     = "10.0.1.10"
}

variable "db_private_ip" {
  description = "Static private IP of the db server."
  type        = string
  default     = "10.0.1.11"
}
