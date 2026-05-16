output "worker_public_ip" {
  description = "Worker VM public IPv4."
  value       = hcloud_server.worker.ipv4_address
}

output "worker_private_ip" {
  description = "Worker VM private IPv4 inside lab4-net."
  value       = var.worker_private_ip
}

output "db_public_ip" {
  description = "DB VM public IPv4 (SSH only — 5432 is blocked externally)."
  value       = hcloud_server.db.ipv4_address
}

output "db_private_ip" {
  description = "DB VM private IPv4 inside lab4-net."
  value       = var.db_private_ip
}

output "inventory_path" {
  description = "Path to the generated Ansible inventory."
  value       = local_file.inventory.filename
}
