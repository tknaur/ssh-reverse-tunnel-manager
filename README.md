# SSH Reverse Tunnel Manager

A production-ready bash script for establishing and managing SSH reverse tunnels via a jump host, enabling secure internet access to your home computer's SSH server.

## Overview

This project provides a complete solution for creating persistent SSH reverse tunnels that allow you to securely access your home computer from anywhere on the internet. The tunnel routes through a remote jump host (VPS, cloud server, etc.) that acts as a proxy, forwarding connections back to your home machine.

**Perfect for:**
- Remote access to home servers/computers
- Access behind firewalls or NAT
- Running services on Raspberry Pi or other home hardware
- Secure remote administration

## Architecture

```
Your Home Computer (SSH :22)
         ↓
SSH Reverse Tunnel (:22 → jump_host:TUNNEL_PORT)
         ↓
jump_host (remote server)
         ↓
Internet Users (connect to jump_host:TUNNEL_PORT)
```

When you connect to `jump_host:TUNNEL_PORT`, the traffic is securely tunneled back to your home computer's SSH server.

## Features

✨ **Core Features:**
- ✅ Fully parameterized configuration
- ✅ SSH key-based authentication
- ✅ Automatic keepalive and reconnection
- ✅ systemd service integration
- ✅ Comprehensive error handling and validation
- ✅ Syslog logging support
- ✅ Process management (start/stop/restart/status)
- ✅ Security hardening in service file

🔧 **Configuration Options:**
- Custom remote hosts and ports
- Flexible tunnel port mapping
- Multiple SSH key support
- Environment variable overrides
- Optional configuration file support

📋 **Production Ready:**
- Auto-restart on failure
- Graceful shutdown with force-kill fallback
- Network dependency management
- Journal logging integration
- Comprehensive documentation

## Project Files

| File | Purpose |
|------|---------|
| `ssh-reverse-tunnel.sh` | Main bash script with tunnel management logic |
| `pi-ssh-tunnel.service` | systemd service unit file for automatic startup |
| `ssh-reverse-tunnel.conf` | Configuration file with parameterized values |
| `SETUP_GUIDE.md` | Detailed installation and troubleshooting guide |
| `README.md` | This file |

## Quick Start

### Prerequisites

- Debian-based Linux system (Ubuntu, Raspberry Pi OS, etc.)
- SSH server running on local machine
- Access to a remote jump host with SSH key authentication
- `bash` and standard Unix utilities (`ssh`, `kill`, `systemctl`)

### Installation

1. **Clone or download the project:**
   ```bash
   git clone <repository-url>
   cd piper
   ```

2. **Install the script and service:**
   ```bash
   sudo cp ssh-reverse-tunnel.sh /usr/local/bin/
   sudo chmod +x /usr/local/bin/ssh-reverse-tunnel.sh
   sudo cp pi-ssh-tunnel.service /etc/systemd/system/
   sudo cp ssh-reverse-tunnel.conf /etc/
   ```

3. **Configure your settings:**
   ```bash
   sudo nano /etc/ssh-reverse-tunnel.conf
   ```
   
   Update with your actual values:
   ```ini
   REMOTE_HOST=your.jump.host.com
   REMOTE_USER=your_username
   REMOTE_PORT=22
   TUNNEL_PORT=2222
   LOCAL_PORT=22
   SSH_KEY=/home/your_user/.ssh/id_rsa
   ```

4. **Set up SSH key authentication:**
   ```bash
   ssh-keygen -t ed25519 -C "home-tunnel-$(hostname)" -f ~/.ssh/id_rsa
   # Copy public key to jump host's ~/.ssh/authorized_keys
   ```

5. **Enable and start the service:**
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable pi-ssh-tunnel
   sudo systemctl start pi-ssh-tunnel
   ```

6. **Verify it's working:**
   ```bash
   sudo systemctl status pi-ssh-tunnel
   sudo journalctl -u pi-ssh-tunnel -f
   ```

## Usage

### As a Systemd Service

```bash
# Start the tunnel
sudo systemctl start pi-ssh-tunnel

# Stop the tunnel
sudo systemctl stop pi-ssh-tunnel

# Restart the tunnel
sudo systemctl restart pi-ssh-tunnel

# Check status
sudo systemctl status pi-ssh-tunnel

# View logs
sudo journalctl -u pi-ssh-tunnel -f
```

### Manual Execution

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

### With Custom Configuration

```bash
# Override environment variables
REMOTE_HOST=custom.host TUNNEL_PORT=3333 /usr/local/bin/ssh-reverse-tunnel.sh start

# Use custom SSH key
SSH_KEY=/path/to/custom/key /usr/local/bin/ssh-reverse-tunnel.sh start
```

## Configuration

### Environment Variables

The script respects the following environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `REMOTE_HOST` | `jump_host` | Jump host hostname or IP |
| `REMOTE_USER` | `tunnel_user` | Username on jump host |
| `REMOTE_PORT` | `22` | SSH port on jump host |
| `TUNNEL_PORT` | `2222` | Port on jump host for reverse tunnel |
| `LOCAL_PORT` | `22` | Local port to forward (typically 22 for SSH) |
| `SSH_KEY` | `~/.ssh/id_rsa` | Path to SSH private key |
| `PID_FILE` | `/var/run/ssh-reverse-tunnel.pid` | PID file location |

### Configuration File

Edit `/etc/ssh-reverse-tunnel.conf` to set default values. The service file will use these when starting.

Example configuration:
```bash
REMOTE_HOST=my-vps.example.com
REMOTE_USER=tunnel
REMOTE_PORT=22
TUNNEL_PORT=2222
LOCAL_PORT=22
SSH_KEY=/home/tunnel/.ssh/id_rsa
```

## Testing the Tunnel

Once the tunnel is established, test it from another machine:

```bash
# SSH through the tunnel
ssh -p 2222 your_user@jump_host

# Other services (if forwarding additional ports)
# Connect to any service running on your home machine
```

## Troubleshooting

### Tunnel won't start

```bash
# Check service status and logs
sudo systemctl status pi-ssh-tunnel
sudo journalctl -u pi-ssh-tunnel -n 50

# Test SSH connection manually
ssh -p YOUR_SSH_PORT tunnel_user@jump_host

# Verify SSH key exists and is readable
ls -la ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa
```

### Connection refused

```bash
# Ensure SSH server is running on local machine
sudo systemctl status ssh

# Check if port 22 is listening
netstat -an | grep :22
```

### Tunnel keeps disconnecting

The script includes keepalive settings to prevent disconnections:
- ServerAliveInterval: 60 seconds
- ServerAliveCountMax: 3

If still disconnecting, check:
- Jump host firewall rules
- Network stability
- SSH server logs on jump host

### Permission issues

```bash
# Ensure correct permissions on SSH key
chmod 600 /home/tunnel_user/.ssh/id_rsa
chmod 700 /home/tunnel_user/.ssh
chmod 700 /home/tunnel_user

# Ensure service user owns the key (if needed)
sudo chown tunnel_user:tunnel_user /home/tunnel_user/.ssh/id_rsa
```

For more troubleshooting tips, see [SETUP_GUIDE.md](SETUP_GUIDE.md).

## Advanced Usage

### Multiple Tunnels

Create separate service files for multiple tunnels:

```bash
sudo cp pi-ssh-tunnel.service /etc/systemd/system/pi-ssh-tunnel-backup.service
sudo nano /etc/systemd/system/pi-ssh-tunnel-backup.service
# Edit Description, Environment variables, and PID file path
sudo systemctl daemon-reload
sudo systemctl enable pi-ssh-tunnel-backup
```

### Custom SSH Key

Specify a custom SSH key in the service file:

```bash
sudo systemctl edit pi-ssh-tunnel
# Add or modify:
# Environment="SSH_KEY=/path/to/custom/key"
sudo systemctl daemon-reload
sudo systemctl restart pi-ssh-tunnel
```

### Monitoring Script

Create a health check:

```bash
#!/bin/bash
while true; do
    if systemctl is-active --quiet pi-ssh-tunnel; then
        echo "$(date): Tunnel OK"
    else
        echo "$(date): Tunnel DOWN - Restarting..."
        sudo systemctl restart pi-ssh-tunnel
    fi
    sleep 300  # Check every 5 minutes
done
```

## Security Considerations

🔒 **Important Security Notes:**

1. **SSH Key Protection**
   - Keep your private key secure (mode 600)
   - Use a passphrase if possible
   - Store backups securely

2. **Port Access**
   - The tunnel port on the jump host is publicly accessible
   - Use firewall rules to restrict connections
   - Consider IP allowlisting

3. **Jump Host Security**
   - Use strong passwords/keys on jump host
   - Disable password authentication if possible
   - Regularly update the jump host

4. **Monitoring**
   - Monitor logs for failed connection attempts
   - Track active connections
   - Set up alerts for tunnel failures

5. **Network**
   - Use key-based authentication only
   - Avoid exposing sensitive services without additional authentication
   - Consider VPN for additional security layers

## Common Issues

### Service starts but tunnel isn't working

Check if SSH service is running:
```bash
sudo systemctl status ssh
```

### Can't find ssh-reverse-tunnel.sh

Ensure it's in the PATH:
```bash
which ssh-reverse-tunnel.sh
# Should return: /usr/local/bin/ssh-reverse-tunnel.sh
```

### Journal shows connection refused

Verify jump host details:
```bash
ssh -vvv -p YOUR_SSH_PORT tunnel_user@jump_host
```

## Uninstallation

```bash
# Stop and disable service
sudo systemctl stop pi-ssh-tunnel
sudo systemctl disable pi-ssh-tunnel

# Remove files
sudo rm /etc/systemd/system/pi-ssh-tunnel.service
sudo rm /usr/local/bin/ssh-reverse-tunnel.sh
sudo rm /etc/ssh-reverse-tunnel.conf

# Reload systemd
sudo systemctl daemon-reload
```

## Contributing

Contributions are welcome! Please:
1. Test changes thoroughly
2. Update documentation
3. Maintain backward compatibility
4. Follow existing code style

## License

This project is provided as-is for educational and personal use.

## Support

For issues and troubleshooting:
1. Check the [SETUP_GUIDE.md](SETUP_GUIDE.md) for detailed troubleshooting
2. Review script comments for implementation details
3. Check systemd journal logs: `sudo journalctl -u pi-ssh-tunnel -f`

## Related Resources

- [SSH Port Forwarding Documentation](https://linux.die.net/man/1/ssh)
- [systemd Service Documentation](https://www.freedesktop.org/software/systemd/man/systemd.service.html)
- [SSH Key Authentication Guide](https://wiki.archlinux.org/title/SSH_keys)

---

**Created with ❤️ for secure remote access**
