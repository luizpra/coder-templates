terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    null = {
      source = "hashicorp/null"
    }
  }
}

provider "coder" {
}

data "coder_workspace" "me" {
}

data "coder_workspace_owner" "me" {
}

data "coder_parameter" "host" {
  name         = "host"
  display_name = "SSH Host"
  description  = "The hostname or IP address of the VM to connect to"
  type         = "string"
  default      = ""
  mutable      = false
}

data "coder_parameter" "username" {
  name         = "username"
  display_name = "SSH Username"
  description  = "The username to use for SSH connection"
  type         = "string"
  default      = "coder"
  mutable      = false
}

data "coder_parameter" "ssh_private_key" {
  name         = "ssh_private_key"
  display_name = "SSH Private Key"
  description  = "The private key to use for SSH authentication"
  type         = "string"
  default      = ""
  mutable      = false
  ephemeral    = true
}

resource "coder_agent" "main" {
  os   = "linux"
  arch = "amd64"

  startup_script = <<-EOT
    #!/bin/bash
    set -e

    # install and start code-server
    if ! command -v code-server &> /dev/null; then
      curl -fsSL https://code-server.dev/install.sh | sh
    fi

    # Start code-server
    code-server --auth none --port 13337 > /tmp/code-server.log 2>&1 &
  EOT

  env = {
    GIT_AUTHOR_NAME     = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_AUTHOR_EMAIL    = data.coder_workspace_owner.me.email
    GIT_COMMITTER_NAME  = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_COMMITTER_EMAIL = data.coder_workspace_owner.me.email
  }

  metadata {
    display_name = "CPU Usage"
    key          = "cpu_usage"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "RAM Usage"
    key          = "ram_usage"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Home Disk"
    key          = "home_disk"
    script       = "coder stat disk --path $HOME"
    interval     = 60
    timeout      = 1
  }
}

resource "coder_app" "code-server" {
  agent_id     = coder_agent.main.id
  slug         = "code-server"
  display_name = "code-server"
  url          = "http://localhost:13337"
  icon         = "/icon/code.svg"
  subdomain    = false
  share        = "owner"

  healthcheck {
    url       = "http://localhost:13337/healthz"
    interval  = 5
    threshold = 6
  }
}

resource "null_resource" "ssh_provision" {
  count = data.coder_workspace.me.start_count

  connection {
    type        = "ssh"
    host        = data.coder_parameter.host.value
    user        = data.coder_parameter.username.value
    private_key = data.coder_parameter.ssh_private_key.value
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p ~/.coder",
      coder_agent.main.init_script,
    ]
  }
}
