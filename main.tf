resource "null_resource" "kexec_nixos" {
  count = var.kexec_tarball_url == null ? 0 : 1
  connection {
    type = "ssh"
    user = var.target_user
    host = var.target_host
    port = var.target_port
    private_key = var.ssh_private_key
  }

  # In theory we could use `cloud-config` here but we want to keep it consistent between bare metal and vms
  provisioner "file" {
    source      = "${path.module}/kexec-nixos.sh"
    destination = "/tmp/kexec-nixos.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/kexec-nixos.sh",
      "if [[ $(id -u) -ne 0 ]]; then sudo /tmp/kexec-nixos.sh '${var.kexec_tarball_url}'; else /tmp/kexec-nixos.sh '${var.kexec_tarball_url}'; fi"
    ]
  }

  # Wait for the kexec to become effective.
  provisioner "remote-exec" {
    inline     = ["sleep 9999"]
    on_failure = continue
  }

  # for debugging
  #triggers = {
  #  v = 2
  #}
  #lifecycle {
  #  ignore_changes  = [triggers]
  #}
}

resource "null_resource" "install_nixos" {
  depends_on = [
    null_resource.kexec_nixos
  ]

  connection {
    type = "ssh"
    host = var.target_host
    port = var.target_port
    private_key = var.ssh_private_key
  }

  provisioner "local-exec" {
    command = "${path.module}/partition-and-copy-nixos.sh ${var.nixos_partitioner_attr} ${var.nixos_system_attr} root@${var.target_host} ${var.target_port}"
    environment = {
      SSH_KEY = var.ssh_private_key == "" ? "-" : var.ssh_private_key
    }
  }

  provisioner "remote-exec" {
    inline = [
      "set -o errexit",
      "nixos-install --no-root-passwd --no-channel-copy --system /run/nixos-install",
      # Retain ssh host key
      "cp -a /etc/ssh/ssh_host_* /mnt/etc/ssh"
    ]
  }

  provisioner "remote-exec" {
    inline = concat(["set -o errexit"], var.post_install_commands)
  }

  # Reboot in the background so we can cleanly finish the script before the hosts go down.
  provisioner "remote-exec" {
    inline = ["systemd-run --on-active=3 shutdown -r now"]
  }

  # Wait for machine to reboot after installation finishes
  provisioner "remote-exec" {
    inline     = ["sleep 9999"]
    on_failure = continue
  }

  # for debugging
  #triggers = {
  #  v = 2
  #}
  #lifecycle {
  #  ignore_changes  = [triggers]
  #}

}
