terraform {
  required_providers {
    tls    = { source = "hashicorp/tls" }
    hcloud = { source = "hetznercloud/hcloud" }
  }
}

# Generate a SSH key-pair
resource "tls_private_key" "hcloud" {
  algorithm = "RSA"
}

# Record the SSH public key into Hetzner Cloud
resource "hcloud_ssh_key" "hcloud" {
  name       = "Terraform user"
  public_key = tls_private_key.hcloud.public_key_openssh
}

# Create hetzner VM
resource "hcloud_server" "test" {
  image       = "debian-10"
  keep_disk   = true
  name        = "test"
  server_type = "cpx21"
  ssh_keys    = [ hcloud_ssh_key.hcloud.id ]
  backups     = false

  labels      = {
    Terraform = true
  }

  lifecycle {
    # Don't destroy server instance if ssh keys changes.
    ignore_changes  = [ssh_keys]
    prevent_destroy = true
  }
}

# Deploy to hetzner VM
module "install-nixos" {
  source = "../.."
  target_host = hcloud_server.test.ipv4_address
  nixos_partitioner_attr = ""
  nixos_system_attr = ""
}
