resource "digitalocean_droplet" "server" {
  count              = var.server_instance_count
  name               = "server-${count.index + 1}"
  tags               = ["nomad", "server"]
  image              = var.do_snapshot_id
  region             = var.do_region
  size               = var.do_size
  private_networking = var.do_private_networking
  ssh_keys           = [data.digitalocean_ssh_key.do.id]

  connection {
    type        = "ssh"
    user        = "root"
    host        = self.ipv4_address
    private_key = "${file("${var.pvt_key}")}"
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "root"
      host        = self.ipv4_address
      private_key = "${file("${var.pvt_key}")}"
    }
    inline = [
      "export VAULT_ADDR=http://127.0.0.1:8200",
      "sed -i 's/node_number/${count.index + 1}/g' /etc/systemd/system/consul-server.service",
      "sed -i 's/server_count/${var.server_instance_count}/g' /etc/systemd/system/consul-server.service",
      "chmod +x /root/configure_consul.sh",
      "/root/configure_consul.sh server",
    ]
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "root"
      host        = self.ipv4_address
      private_key = "${file("${var.pvt_key}")}"
    }
    inline = [
      "export VAULT_ADDR=http://127.0.0.1:8200",
      "consul join ${digitalocean_droplet.server.0.ipv4_address_private}",
    ]
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "root"
      host        = self.ipv4_address
      private_key = "${file("${var.pvt_key}")}"
    }
    inline = [
      "export VAULT_ADDR=http://127.0.0.1:8200",
      "chmod +x /root/enable_vault.sh",
      "/root/enable_vault.sh",
    ]
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "root"
      host        = self.ipv4_address
      private_key = "${file("${var.pvt_key}")}"
    }
    inline = [
      "export VAULT_ADDR=http://127.0.0.1:8200",
      "vault status",
      "chmod +x /root/init_vault.sh",
      "/root/init_vault.sh ${count.index}",
    ]
  }

  provisioner "local-exec" {
    command = "scp -o StrictHostKeyChecking=no root@${digitalocean_droplet.server.0.ipv4_address}:/root/startupOutput.txt tmp/vaultDetails.txt"
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "root"
      host        = self.ipv4_address
      private_key = "${file("${var.pvt_key}")}"
    }
    inline = [
      "chmod +x /root/configure_nomad.sh",
      "sed -i 's/server_ip_bind_addr/0.0.0.0/g' /root/nomad-server.hcl",
      "sed -i 's/server_ip/${self.ipv4_address_private}/g' /root/nomad-server.hcl",
      "sed -i 's/server_count/${var.server_instance_count}/g' /root/nomad-server.hcl",
      "sed -i \"s/replace_vault_token/$(sed -n -e 's/^Initial Root Token: //p' /root/startupOutput.txt)/g\" /etc/systemd/system/nomad-server.service",
      "/root/configure_nomad.sh server",
    ]
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "root"
      host        = self.ipv4_address
      private_key = "${file("${var.pvt_key}")}"
    }
    inline = [
      "export NOMAD_ADDR=http://${self.ipv4_address_private}:4646",
      "nomad server join ${digitalocean_droplet.server.0.ipv4_address_private}",
    ]
  }

  provisioner "local-exec" {
    command = "echo ${digitalocean_droplet.server.0.ipv4_address_private} > tmp/private_server.txt"
  }

  provisioner "local-exec" {
    command = "echo ${digitalocean_droplet.server.0.ipv4_address} > tmp/public_server.txt"
  }
}

resource "null_resource" "dependency_manager" {
  triggers = {
    dependency_id = digitalocean_droplet.server[0].ipv4_address_private
  }
}

resource "digitalocean_droplet" "client" {
  count              = var.client_instance_count
  name               = "client-${count.index + 1}"
  tags               = ["nomad", "client"]
  image              = var.do_snapshot_id
  region             = var.do_region
  size               = var.do_size
  private_networking = var.do_private_networking
  ssh_keys           = [data.digitalocean_ssh_key.do.id]
  depends_on         = [null_resource.dependency_manager]

  connection {
    type        = "ssh"
    user        = "root"
    host        = self.ipv4_address
    private_key = "${file("${var.pvt_key}")}"
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "root"
      host        = self.ipv4_address
      private_key = "${file("${var.pvt_key}")}"
    }
    inline = [
      "sed -i 's/node_number/${count.index + 1}/g' /etc/systemd/system/consul-client.service",
      "chmod +x /root/configure_consul.sh",
      "/root/configure_consul.sh client ${digitalocean_droplet.server[0].ipv4_address_private}",
    ]
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "root"
      host        = self.ipv4_address
      private_key = "${file("${var.pvt_key}")}"
    }
    inline = [
      "chmod +x /root/configure_nomad.sh",
      "/root/configure_nomad.sh client",
    ]
  }
}

output "consul_server_ip" {
  value = digitalocean_droplet.server[0].ipv4_address_private
}

output "server_ids" {
  value = [digitalocean_droplet.server.*.id]
}

output "client_ids" {
  value = [digitalocean_droplet.client.*.id]
}
