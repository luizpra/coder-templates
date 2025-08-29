terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    docker = {
      source = "kreuzwerker/docker"
    }
    ad = {
      source  = "hashicorp/ad"
      version = "0.5.0"
    }
  }
}

locals {
  username = data.coder_workspace_owner.me.name
}

variable "bws_access_token" {
  description = "Bws access token"
  type        = strin
  sensitive   = true
  default     = "afafa"
}

variable "user_id" {
  description = "User id on host system, used to set permissions on the home"
  type        = number
  default     = 999
}

data "coder_provisioner" "me" {
}

provider "docker" {
}

provider "coder" {
}

data "coder_workspace" "me" {
}

data "coder_workspace_owner" "me" {
}

data "coder_parameter" "bws_access_token" {
  name         = "bws_access_token"
  display_name = "BWS Access TOKEN"
  type         = "string"
  default      = "123456"
  mutable      = true
  ephemeral    = true
  order        = 1
}

data "coder_parameter" "docker_group" {
  name        = "docker-group"
  description = "Docker group on host"
  type        = "number"
  default     = 999
}

data "coder_parameter" "java_version" {
  name = "java-version"
  description = "JDK runtime version"
  mutable = true
  type = "number"
  default = 11
  
  option {
    name = "17"
    value = 17
  }

  option {
    name = "11"
    value = 11
  }
  
  option {
    name = "8"
    value = 8
  }
}

resource "coder_agent" "main" {
  arch           = data.coder_provisioner.me.arch
  os             = "linux"
  startup_script = <<-EOT
    set -e

    echo "diplaying it ..."
    echo ${var.bws_access_token}
    echo "-----------------------"


    # install and start code-server
    curl -fsSL https://code-server.dev/install.sh | sh -s -- --method=standalone --prefix=/tmp/code-server
    /tmp/code-server/bin/code-server --auth none --port 13337 >/tmp/code-server.log 2>&1 &
    cd /tmp
    curl -sL https://releases.hashicorp.com/terraform/1.12.2/terraform_1.12.2_linux_amd64.zip | funzip | sudo tee /usr/local/bin/terraform > /dev/null && sudo chmod +x /usr/local/bin/terraform
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.29.0/kind-linux-amd64 && chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && chmod +x kubectl && sudo mv kubectl /usr/local/bin/kubectl
    curl -L https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv5.7.0/kustomize_v5.7.0_linux_amd64.tar.gz | tar xz && sudo mv kustomize /usr/local/bin/kustomize
    curl -s https://fluxcd.io/install.sh | sudo bash
    curl -L https://github.com/derailed/k9s/releases/download/v0.50.7/k9s_Linux_amd64.tar.gz | tar xz k9s && chmod +x k9s && sudo mv k9s /usr/local/bin/k9s
    curl -sL https://github.com/bitwarden/sdk-sm/releases/download/bws-v1.0.0/bws-x86_64-unknown-linux-gnu-1.0.0.zip | funzip | sudo tee /usr/local/bin/bws > /dev/null && sudo chmod +x /usr/local/bin/bws

    echo "creating home directory for user ${local.username} with uid ${var.user_id}"
    sudo mkdir -p /home/${local.username} && sudo chown ${local.username}:${local.username} /home/${local.username}
    echo "home: $HOME"
    ls -lah /home/
    if [ -f "$HOME/.bashrc" ]; then
      echo "Bash files already setup ..."
      exit 0
    fi

    cp /etc/skel/.bashrc /home/${local.username}/
    echo 'if [ -f "$HOME/.bashrc" ]; then
       . "$HOME/.bashrc"
    fi' | tee -a ~/.bash_profile

    echo 'source <(kubectl completion bash)' >>~/.bashrc
    echo 'alias k=kubectl' >>~/.bashrc
    echo 'complete -o default -F __start_kubectl k' >>~/.bashrc
    echo 'set -o vi' >>~/.bashrc
    . <(flux completion bash)

  EOT

  env = {
    GIT_AUTHOR_NAME     = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_AUTHOR_EMAIL    = "${data.coder_workspace_owner.me.email}"
    GIT_COMMITTER_NAME  = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_COMMITTER_EMAIL = "${data.coder_workspace_owner.me.email}"
    BWS_ACCESS_TOKEN    = "${var.bws_access_token}"
  }

  metadata {
    display_name = "CPU Usage"
    key          = "0_cpu_usage"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "RAM Usage"
    key          = "1_ram_usage"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Home Disk"
    key          = "3_home_disk"
    script       = "coder stat disk --path $${HOME}"
    interval     = 60
    timeout      = 1
  }

  metadata {
    display_name = "CPU Usage (Host)"
    key          = "4_cpu_usage_host"
    script       = "coder stat cpu --host"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Memory Usage (Host)"
    key          = "5_mem_usage_host"
    script       = "coder stat mem --host"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Load Average (Host)"
    key          = "6_load_host"
    # get load avg scaled by number of cores
    script   = <<EOT
      echo "`cat /proc/loadavg | awk '{ print $1 }'` `nproc`" | awk '{ printf "%0.2f", $1/$2 }'
    EOT
    interval = 60
    timeout  = 1
  }

  metadata {
    display_name = "Swap Usage (Host)"
    key          = "7_swap_host"
    script       = <<EOT
      free -b | awk '/^Swap/ { printf("%.1f/%.1f", $3/1024.0/1024.0/1024.0, $2/1024.0/1024.0/1024.0) }'
    EOT
    interval     = 10
    timeout      = 1
  }
}

resource "coder_app" "code-server" {
  agent_id     = coder_agent.main.id
  slug         = "code-server"
  display_name = "code-server"
  url          = "http://localhost:13337/?folder=/home/${local.username}"
  icon         = "/icon/code.svg"
  subdomain    = false
  share        = "owner"

  healthcheck {
    url       = "http://localhost:13337/healthz"
    interval  = 5
    threshold = 6
  }
}

resource "docker_volume" "home_volume" {
  name = "coder-${data.coder_workspace.me.id}-home"
  # Protect the volume from being deleted due to changes in attributes.
  lifecycle {
    ignore_changes = all
  }
}

resource "docker_image" "main" {
  name = "coder-${data.coder_workspace.me.id}"
  build {
    context = "./build"
    build_args = {
      USER    = local.username
      USER_ID = var.user_id
      GUID    = data.coder_parameter.docker_group.value
      JAVA_VERSION = data.coder_parameter.java_version.value
    }
    no_cache = true
  }
  triggers = {
    dir_sha1 = sha1(join("", [for f in fileset(path.module, "build/*") : filesha1(f)]))
  }
}

resource "docker_network" "pipeline" {
  name   = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"
  driver = "bridge"
}

resource "docker_container" "workspace" {
  count = data.coder_workspace.me.start_count
  image = docker_image.main.name
  # Uses lower() to avoid Docker restriction on container names.
  name = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"
  # Hostname makes the shell more user friendly: coder@my-workspace:~$
  hostname = data.coder_workspace.me.name
  # Use the docker gateway if the access URL is 127.0.0.1
  entrypoint = [
    "sh", "-c", replace(coder_agent.main.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")
  ]
  env = [
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
  ]
  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }
  volumes {
    container_path = "/home/${local.username}"
    volume_name    = docker_volume.home_volume.name
    read_only      = false
  }
  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
    read_only      = true
  }
  networks_advanced {
    name = docker_network.pipeline.name
  }
}

module "jetbrains_gateway" {
 count          = data.coder_workspace.me.start_count
 source         = "registry.coder.com/modules/jetbrains-gateway/coder"
 version        = "1.0.25"
 agent_id       = coder_agent.main.id
 agent_name     = "main"
 folder         = "/home/${local.username}"
 jetbrains_ides = ["CL", "GO", "IU", "PY", "WS"]
 default        = "IU"
}

module "filebrowser" {
  count         = data.coder_workspace.me.start_count
  source        = "registry.coder.com/modules/filebrowser/coder"
  version       = "1.0.23"
  agent_name    = "main"
  agent_id      = coder_agent.main.id
  subdomain     = false
  database_path = ".config/filebrowser.db"
}

#
#module "jupyterlab" {
#  count    = data.coder_workspace.me.start_count
#  source   = "registry.coder.com/modules/jupyterlab/coder"
#  version  = "1.0.23"
#  agent_id = coder_agent.main.id
#  subdomain = false
#}

# resource "coder_script" "calibre" {
#   agent_id     = coder_agent.main.id
#   display_name = "Calibre"
#   script       = "calibre-server --disable-auth --port 8084 /home/luiz/.calibre-library >>/dev/null 2>&1 &"
#   run_on_start = true
# }

# resource "coder_app" "calibre" {
#   agent_id     = coder_agent.main.id
#   slug         = "calibre"
#   display_name = "calibre"
#   icon         = "${data.coder_workspace.me.access_url}/icon/code.svg"
#   url          = "http://localhost:8084"
#   share        = "owner"
#   subdomain    = false
# }

# module "kasmvnc" {
#   count               = data.coder_workspace.me.start_count
#   source              = "registry.coder.com/coder/kasmvnc/coder"
#   version             = "0.2.0"
#   agent_id            = coder_agent.main.id
#   desktop_environment = "xfce"
#   subdomain           = true
# }

resource "coder_script" "test" {
  agent_id     = coder_agent.main.id
  display_name = "test"
  icon         = "/icon/database.svg"
  cron         = "0 */5 * * * * "
  script       = <<EOF
    #!/bin/sh
    echo "Hello from Coder script! time now is $(date)" >> /tmp/test-script.log
  EOF
}

