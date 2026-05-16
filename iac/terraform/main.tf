provider "hcloud" {
  token = var.hcloud_token
}

resource "hcloud_ssh_key" "ansible" {
  name       = "lab4-ansible"
  public_key = var.ssh_public_key
}

resource "hcloud_network" "lab4" {
  name     = "lab4-net"
  ip_range = "10.0.0.0/16"
}

resource "hcloud_network_subnet" "lab4" {
  network_id   = hcloud_network.lab4.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = var.private_cidr
}

# Firewall — worker: public SSH + HTTP only.
resource "hcloud_firewall" "worker" {
  name = "lab4-worker-fw"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "80"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}

# Firewall — db: public SSH only; 5432 is reachable only via the private network
# (Hetzner firewalls apply to the public NIC; private-NIC traffic between hosts
# in the same private subnet is unfiltered by design).
resource "hcloud_firewall" "db" {
  name = "lab4-db-fw"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}

resource "hcloud_server" "worker" {
  name         = "lab4-worker"
  image        = var.image
  server_type  = var.server_type
  location     = var.location
  ssh_keys     = [hcloud_ssh_key.ansible.id]
  firewall_ids = [hcloud_firewall.worker.id]

  user_data = templatefile("${path.module}/cloud-init.ansible.yaml.tftpl", {
    ssh_public_key = var.ssh_public_key
  })

  network {
    network_id = hcloud_network.lab4.id
    ip         = var.worker_private_ip
  }

  depends_on = [hcloud_network_subnet.lab4]
}

resource "hcloud_server" "db" {
  name         = "lab4-db"
  image        = var.image
  server_type  = var.server_type
  location     = var.location
  ssh_keys     = [hcloud_ssh_key.ansible.id]
  firewall_ids = [hcloud_firewall.db.id]

  user_data = templatefile("${path.module}/cloud-init.ansible.yaml.tftpl", {
    ssh_public_key = var.ssh_public_key
  })

  network {
    network_id = hcloud_network.lab4.id
    ip         = var.db_private_ip
  }

  depends_on = [hcloud_network_subnet.lab4]
}

# Render Ansible inventory next to the playbook so `ansible-playbook -i ../ansible/inventory/hosts.ini ...` works.
resource "local_file" "inventory" {
  filename        = "${path.module}/../ansible/inventory/hosts.ini"
  file_permission = "0644"

  content = templatefile("${path.module}/inventory.ini.tftpl", {
    worker_public_ip  = hcloud_server.worker.ipv4_address
    worker_private_ip = var.worker_private_ip
    db_public_ip      = hcloud_server.db.ipv4_address
    db_private_ip     = var.db_private_ip
  })
}
