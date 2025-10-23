# Scratch Template

This template provisions a Coder workspace on an existing VM over SSH. It installs and configures code-server for remote development.

## Features

- Connects to an existing VM via SSH
- Installs and configures code-server
- Provides metrics (CPU, RAM, Disk usage)
- Git configuration based on workspace owner

## Parameters

The template requires the following parameters when creating a workspace:

- **SSH Host**: The hostname or IP address of the VM to connect to
- **SSH Username**: The username to use for SSH connection (default: `coder`)
- **SSH Private Key**: The private key to use for SSH authentication (ephemeral parameter, not stored)

## Requirements

The target VM must:
- Be accessible via SSH
- Run Linux
- Have bash installed
- Have internet access to download code-server

## Usage

1. Push this template to your Coder deployment:
   ```sh
   coder templates push scratch -d ./scratch
   ```

2. Create a workspace using this template and provide:
   - The SSH host/IP address
   - SSH username
   - SSH private key (for authentication)

3. The workspace will:
   - Connect to the VM via SSH
   - Install code-server (if not already installed)
   - Start code-server on port 13337
   - Make it available through the Coder dashboard

## Applications

- **code-server**: Web-based VS Code editor accessible through the Coder dashboard

## Notes

- The SSH private key is marked as ephemeral and won't be stored permanently
- code-server runs without authentication as it's accessed through Coder's authenticated proxy
- The template uses `start_count` to only provision when the workspace is started
