# SSH Reverse Tunnel Setup Guide

## Overview
This setup allows you to access your home computer's SSH server from the internet via a reverse tunnel through a jump host.

**Tunnel Architecture:**
```
Your Home Computer (SSH on port 22)
         ↓
SSH Reverse Tunnel (:22 → jump_host:2222)
         ↓
jump_host (tunnel_user, port 22)
         ↓
Internet Users (connect to jump_host:2222)
```

## Prerequisites

1. **Debian-based system** (Ubuntu, Raspberry Pi OS, etc.)
2. **SSH server running** on your home computer (port 22)
3. **Access to jump host** with a user account (e.g., tunnel_user)
4. **SSH key authentication** configured (recommended)

## Installation Steps

### Step 1: Set Up SSH Key Authentication

On your home computer (as the tunnel_user or whichever user will run the service):

```bash
# Generate SSH key if you don't have one
ssh-keygen -t ed25519 -C "home-tunnel-$(hostname)" -f ~/.ssh/id_rsa

# Test connection to jump host (replace values with your actual configuration)
ssh -p YOUR_SSH_PORT tunnel_user@jump_host "echo 'Connection successful'"

# Ensure correct permissions
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub
```

If key-based authentication is not yet set up on the jump host, you may need to:
1. Add your public key to `~/.ssh/authorized_keys` on the jump host
2. Or configure password-based SSH first and then add your key

### Step 2: Install the Script

```bash
# Copy script to system location
sudo cp ssh-reverse-tunnel.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/ssh-reverse-tunnel.sh

# Copy configuration file (optional)
sudo cp ssh-reverse-tunnel.conf /etc/
```

### Step 3: Install as Systemd Service

```bash
# Copy service file
sudo cp pi-ssh-tunnel.service /etc/systemd/system/

# Reload systemd daemon
sudo systemctl daemon-reload

# Enable service to start on boot
sudo systemctl enable pi-ssh-tunnel

# Start the service
sudo systemctl start pi-ssh-tunnel

# Check status
sudo systemctl status pi-ssh-tunnel
```

### Step 4: Verify Tunnel is Working

```bash
# Check if service is running
sudo systemctl status pi-ssh-tunnel

# Check journal logs
sudo journalctl -u pi-ssh-tunnel -f

# From another machine, test SSH connection through tunnel (replace values with your actual configuration)
ssh -p YOUR_TUNNEL_PORT tunnel_user@jump_host
```

## Configuration

### Via Environment Variables

Edit `/etc/systemd/system/pi-ssh-tunnel.service` and modify the `Environment=` lines:

```bash
sudo systemctl edit pi-ssh-tunnel
```

Then set your custom values:
```ini
Environment="REMOTE_HOST=your.jump.host"
Environment="TUNNEL_PORT=2222"
```

Reload and restart:
```bash
sudo systemctl daemon-reload
sudo systemctl restart pi-ssh-tunnel
```

### Via Configuration File

Edit `/etc/ssh-reverse-tunnel.conf` with your custom values:

```bash
sudo nano /etc/ssh-reverse-tunnel.conf
```

Example configuration:
```ini
REMOTE_HOST=jump_host
REMOTE_USER=tunnel_user
REMOTE_PORT=22
TUNNEL_PORT=2222
LOCAL_PORT=22
SSH_KEY=/home/tunnel_user/.ssh/id_rsa
```

Then source it in the service file or modify the ExecStart line.

## Manual Operation

If you need to run the script manually (e.g., for debugging):

```bash
# Start tunnel
/usr/local/bin/ssh-reverse-tunnel.sh start

# Check status
/usr/local/bin/ssh-reverse-tunnel.sh status

# Stop tunnel
/usr/local/bin/ssh-reverse-tunnel.sh stop

# Restart tunnel
/usr/local/bin/ssh-reverse-tunnel.sh restart
```

## Troubleshooting

### Service won't start

```bash
# Check service status and error messages
sudo systemctl status pi-ssh-tunnel
sudo journalctl -u pi-ssh-tunnel -n 50

# Check if SSH key is readable by the tunnel user
ls -la ~/.ssh/id_rsa

# Verify SSH key permissions
chmod 600 ~/.ssh/id_rsa
```

### Can't connect through tunnel

```bash
# Test direct connection to jump host (replace values with your actual configuration)
ssh -p YOUR_SSH_PORT tunnel_user@jump_host

# Check if tunnel process is running
ps aux | grep "ssh.*TUNNEL_PORT"

# Check for firewall issues
sudo ufw allow YOUR_TUNNEL_PORT
```

### SSH key permission issues

```bash
# Ensure proper key permissions (must be 600)
chmod 600 /home/tunnel_user/.ssh/id_rsa

# Ensure proper home directory permissions
chmod 700 /home/tunnel_user/.ssh
chmod 700 /home/tunnel_user
```

### Connection timeout

Check that:
1. Jump host port (replace YOUR_SSH_PORT with your actual port) is accessible
2. Local SSH server is running on port 22
3. No firewall blocking connections

## Monitoring

### Check tunnel status regularly

```bash
# View service status
sudo systemctl status pi-ssh-tunnel

# View recent logs
sudo journalctl -u pi-ssh-tunnel --since "10 minutes ago"

# Monitor in real-time
sudo journalctl -u pi-ssh-tunnel -f
```

### Create monitoring script

```bash
#!/bin/bash
while true; do
    if systemctl is-active --quiet pi-ssh-tunnel; then
        echo "$(date): Tunnel OK"
    else
        echo "$(date): Tunnel DOWN - Restarting..."
        sudo systemctl restart pi-ssh-tunnel
    fi
    sleep 300
done
```

## Security Considerations

1. **SSH Key Protection**: Keep your private key secure with proper permissions (600)
2. **Port Access**: The tunnel port (YOUR_TUNNEL_PORT) on the jump host is publicly accessible - restrict who can connect
3. **Network Monitoring**: Monitor active connections to detect unauthorized access
4. **Regular Updates**: Keep your system and SSH updated
5. **Log Monitoring**: Regularly check logs for failed connection attempts

## Advanced Usage

### Custom SSH Key for Service

If using a different SSH key than the default:

```bash
sudo nano /etc/systemd/system/pi-ssh-tunnel.service
# Change: Environment="SSH_KEY=/path/to/custom/key"
sudo systemctl daemon-reload
sudo systemctl restart pi-ssh-tunnel
```

### Running Multiple Tunnels

Create separate service files for multiple tunnels:

```bash
# Create second service
sudo cp pi-ssh-tunnel.service /etc/systemd/system/pi-ssh-tunnel-backup.service

# Edit the second service
sudo nano /etc/systemd/system/pi-ssh-tunnel-backup.service
# Change name and port
```

### Using Dropbear SSH Client

For resource-constrained devices like Raspberry Pi, you can use **Dropbear**, a lightweight SSH client alternative:

#### Installation

```bash
# Debian/Raspberry Pi OS
sudo apt install dropbear

# Then enable it in the service
sudo systemctl edit pi-ssh-tunnel
# Add or modify line:
# Environment="SSH_CLIENT=dropbear"

sudo systemctl daemon-reload
sudo systemctl restart pi-ssh-tunnel
```

#### Manual Usage

```bash
# Test with dropbear
SSH_CLIENT=dropbear /usr/local/bin/ssh-reverse-tunnel.sh start

# Check status
/usr/local/bin/ssh-reverse-tunnel.sh status

# Stop tunnel
/usr/local/bin/ssh-reverse-tunnel.sh stop
```

**Server Compatibility:** The dropbear client (`dbclient`) works with both OpenSSH `sshd` and Dropbear `sshd` servers on your jump host. Both are fully compatible.

#### Configuration File

Edit `/etc/ssh-reverse-tunnel.conf`:

```bash
SSH_CLIENT=dropbear
DROPBEAR_OPTS=-y
```

Then reload the service:

```bash
sudo systemctl daemon-reload
sudo systemctl restart pi-ssh-tunnel
```

#### Why Dropbear?

- **Memory efficient:** ~1-2 MB vs ~10-20 MB for OpenSSH
- **Lightweight:** Perfect for Raspberry Pi and embedded devices
- **Sufficient for reverse tunneling:** Has all features needed for SSH port forwarding
- **Low CPU usage:** Minimal processing overhead

#### Troubleshooting Dropbear

If the tunnel won't start with dropbear:

```bash
# Check if dbclient is installed
which dbclient

# Test connection manually
dbclient -y -i ~/.ssh/id_rsa -p YOUR_SSH_PORT tunnel_user@jump_host

# Check logs
sudo journalctl -u pi-ssh-tunnel -f

# Verify SSH key permissions
chmod 600 ~/.ssh/id_rsa
```

**Note:** Dropbear has fewer options than OpenSSH. If you need advanced SSH features, stick with OpenSSH.

### Load Configuration from File

Modify the ExecStart line to source the config file:

```bash
ExecStart=/bin/bash -c 'source /etc/ssh-reverse-tunnel.conf && /usr/local/bin/ssh-reverse-tunnel.sh start'
```

## Uninstallation

```bash
# Stop the service
sudo systemctl stop pi-ssh-tunnel

# Disable from boot
sudo systemctl disable pi-ssh-tunnel

# Remove service file
sudo rm /etc/systemd/system/pi-ssh-tunnel.service

# Remove script
sudo rm /usr/local/bin/ssh-reverse-tunnel.sh

# Remove config (optional)
sudo rm /etc/ssh-reverse-tunnel.conf

# Reload systemd
sudo systemctl daemon-reload
```
