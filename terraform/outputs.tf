output "nodes" {
  value = {
    for name, vm in yandex_compute_instance.node : name => {
      public_ip  = vm.network_interface[0].nat_ip_address
      private_ip = vm.network_interface[0].ip_address
    }
  }
}

output "ansible_inventory" {
  value = yamlencode({
    all = {
      vars = {
        ansible_user                 = "ubuntu"
        ansible_ssh_private_key_file = pathexpand(var.ssh_private_key_path)
        ansible_python_interpreter   = "/usr/bin/python3"
      }

      children = {
        managers = {
          hosts = {
            "swarm-manager" = {
              ansible_host = yandex_compute_instance.node["swarm-manager"].network_interface[0].nat_ip_address
              swarm_ip     = local.nodes["swarm-manager"]
            }
          }
        }

        workers = {
          hosts = {
            for name, ip in local.nodes : name => {
              ansible_host = yandex_compute_instance.node[name].network_interface[0].nat_ip_address
              swarm_ip     = ip
            }
            if name != "swarm-manager"
          }
        }
      }
    }
  })
}
