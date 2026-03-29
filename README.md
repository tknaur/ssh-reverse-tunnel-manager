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
- ✅ Health monitoring and auto-restart
- ✅ Comprehensive error handling and validation
- ✅ Syslog logging support
- ✅ Process management (start/stop/restart/status)
- ✅ Security hardening in service file
- ✅ OpenSSH and Dropbear SSH client support

🔧 **Configuration Options:**
- Custom remote hosts and ports
- Flexible tunnel port mapping
- Multiple SSH key support
- Environment variable overrides
- Optional configuration file support
- Choice of SSH client (OpenSSH or Dropbear)

📋 **Production Ready:**
- Auto-restart on failure with health monitoring
- Graceful shutdown with force-kill fallback
- Periodic tunnel health checks via systemd timer
- Network dependency management
- Journal logging integration
- Comprehensive documentation

## Project Files

| File | Purpose |
|------|---------|
| `ssh-reverse-tunnel.sh` | Main bash script with tunnel management logic |
| `ssh-reverse-tunnel.service` | systemd service unit file for automatic startup |
| `ssh-reverse-tunnel.conf` | Configuration file with parameterized values |
| `monitor-tunnel.sh` | Health check script for monitoring and auto-restart |
| `ssh-reverse-tunnel-monitor.service` | systemd service for monitor script |
| `ssh-reverse-tunnel-monitor.timer` | systemd timer for periodic health checks |
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
    cd ssh-reverse-tunnel-manager
    ```

2. **Install the script and service:**
    ```bash
    sudo cp ssh-reverse-tunnel.sh /usr/local/bin/
    sudo chmod +x /usr/local/bin/ssh-reverse-tunnel.sh
    sudo cp monitor-tunnel.sh /usr/local/bin/
    sudo chmod +x /usr/local/bin/monitor-tunnel.sh
    sudo cp ssh-reverse-tunnel.service /etc/systemd/system/
    sudo cp ssh-reverse-tunnel-monitor.service /etc/systemd/system/
    sudo cp ssh-reverse-tunnel-monitor.timer /etc/systemd/system/
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
    sudo systemctl enable ssh-reverse-tunnel
    sudo systemctl start ssh-reverse-tunnel
    ```

6. **Enable monitoring and auto-restart:**
    ```bash
    sudo systemctl enable ssh-reverse-tunnel-monitor.timer
    sudo systemctl start ssh-reverse-tunnel-monitor.timer
    ```

7. **Verify it's working:**
    ```bash
    sudo systemctl status ssh-reverse-tunnel
    sudo systemctl status ssh-reverse-tunnel-monitor.timer
    sudo journalctl -u ssh-reverse-tunnel -f
    ```

## Usage

### As a Systemd Service

```bash
# Start the tunnel
sudo systemctl start ssh-reverse-tunnel

# Stop the tunnel
sudo systemctl stop ssh-reverse-tunnel

# Restart the tunnel
sudo systemctl restart ssh-reverse-tunnel

# Check status
sudo systemctl status ssh-reverse-tunnel

# View logs
sudo journalctl -u ssh-reverse-tunnel -f
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

### Monitoring

The monitoring script automatically checks tunnel health every minute and restarts if needed:

```bash
# View monitor status
sudo systemctl status ssh-reverse-tunnel-monitor.timer

# View monitor logs
sudo journalctl -u ssh-reverse-tunnel-monitor.service -f

# Check next scheduled run
systemctl list-timers ssh-reverse-tunnel-monitor.timer
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
| `SSH_CLIENT` | `openssh` | SSH client to use: `openssh` or `dropbear` |
| `DROPBEAR_OPTS` | `-y` | Additional options for dropbear's `dbclient` |
| `PID_FILE` | `/var/run/ssh-reverse-tunnel.pid` | PID file location |
| `DEBUG` | `0` | Set to `1` to show SSH output for debugging |

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

## Important: Jump Host Configuration

For the reverse tunnel to be accessible from the internet, your jump host must have `GatewayPorts` enabled:

```bash
# On your jump host:
sudo nano /etc/ssh/sshd_config

# Add or modify this line:
GatewayPorts yes

# Reload SSH:
sudo systemctl reload sshd
```

Without this setting, the tunnel port will only be accessible from localhost on the jump host.

## Testing the Tunnel

Once the tunnel is established, test it from another machine:

```bash
# SSH through the tunnel
ssh -p 2222 your_user@jump_host

# Or using the tunnel for other services
ssh -p 2222 -l your_user jump_host
```

## Troubleshooting

### Tunnel won't start

```bash
# Check service status and logs
sudo systemctl status ssh-reverse-tunnel
sudo journalctl -u ssh-reverse-tunnel -n 50

# Test SSH connection manually
ssh -p YOUR_SSH_PORT tunnel_user@jump_host

# Verify SSH key exists and is readable
ls -la ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa
```

### Connection refused from internet

```bash
# Check if tunnel port is listening on jump host
ssh jump_host "netstat -tlnp | grep TUNNEL_PORT"

# Verify GatewayPorts is enabled on jump host
ssh jump_host "grep GatewayPorts /etc/ssh/sshd_config"
```

### Connection refused locally

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
sudo cp ssh-reverse-tunnel.service /etc/systemd/system/ssh-reverse-tunnel-backup.service
sudo nano /etc/systemd/system/ssh-reverse-tunnel-backup.service
# Edit Description, Environment variables, and PID file path
sudo systemctl daemon-reload
sudo systemctl enable ssh-reverse-tunnel-backup
```

### Custom SSH Key

Specify a custom SSH key in the service file:

```bash
sudo systemctl edit ssh-reverse-tunnel
# Add or modify:
# Environment="SSH_KEY=/path/to/custom/key"
sudo systemctl daemon-reload
sudo systemctl restart ssh-reverse-tunnel
```

## Dropbear SSH Client Support

For resource-constrained devices (Raspberry Pi, IoT devices), this script supports **Dropbear**, a lightweight SSH implementation that uses significantly less memory and CPU than OpenSSH.

### Installation

**Debian/Raspberry Pi OS:**
```bash
sudo apt install dropbear
```

**Other distributions:** Check your package manager for `dropbear`.

### Using Dropbear

Simply set the `SSH_CLIENT` environment variable to `dropbear`:

```bash
# Run with Dropbear
SSH_CLIENT=dropbear /usr/local/bin/ssh-reverse-tunnel.sh start

# Or set it in the config file
echo "SSH_CLIENT=dropbear" >> /etc/ssh-reverse-tunnel.conf

# Or override in systemd service
sudo systemctl edit ssh-reverse-tunnel
# Add line: Environment="SSH_CLIENT=dropbear"
sudo systemctl daemon-reload
sudo systemctl restart ssh-reverse-tunnel
```

**Compatibility Note:** Dropbear's `dbclient` is compatible with both OpenSSH `sshd` and Dropbear `sshd` on the remote jump host. You can use either server type on your remote machine.

### Dropbear Options

You can customize dropbear's `dbclient` behavior using `DROPBEAR_OPTS`:

```bash
# Default: auto-accept host keys
DROPBEAR_OPTS=-y

# Example: disable password authentication and auto-accept keys
DROPBEAR_OPTS="-s -y"

# Then run:
SSH_CLIENT=dropbear /usr/local/bin/ssh-reverse-tunnel.sh start
```

**Common dbclient options:**
- `-y`: Accept new host keys automatically
- `-s`: Disable password authentication
- `-T`: Disable pseudo-terminal allocation
- `-N`: Don't execute a shell on the remote side (used by default)

Run `dbclient -h` for a complete list of options.

### Memory Comparison

**OpenSSH client:**
- Typical memory footprint: 10-20 MB
- Best for: Full-featured SSH with many options

**Dropbear:**
- Typical memory footprint: 1-2 MB  
- Best for: Lightweight SSH on embedded/IoT devices
- Trade-off: Fewer configuration options, but sufficient for reverse tunneling

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
   - The included monitoring script auto-restarts failed tunnels

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

### Debug mode

Enable debug output to see SSH errors:
```bash
DEBUG=1 /usr/local/bin/ssh-reverse-tunnel.sh start
```

## Uninstallation

```bash
# Stop and disable service
sudo systemctl stop ssh-reverse-tunnel
sudo systemctl disable ssh-reverse-tunnel

# Stop and disable monitor timer
sudo systemctl stop ssh-reverse-tunnel-monitor.timer
sudo systemctl disable ssh-reverse-tunnel-monitor.timer

# Remove files
sudo rm /etc/systemd/system/ssh-reverse-tunnel.service
sudo rm /etc/systemd/system/ssh-reverse-tunnel-monitor.service
sudo rm /etc/systemd/system/ssh-reverse-tunnel-monitor.timer
sudo rm /usr/local/bin/ssh-reverse-tunnel.sh
sudo rm /usr/local/bin/monitor-tunnel.sh
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
3. Check systemd journal logs: `sudo journalctl -u ssh-reverse-tunnel -f`
4. Enable debug mode: `DEBUG=1 ssh-reverse-tunnel.sh start`

## Related Resources

- [SSH Port Forwarding Documentation](https://linux.die.net/man/1/ssh)
- [systemd Service Documentation](https://www.freedesktop.org/software/systemd/man/systemd.service.html)
- [SSH Key Authentication Guide](https://wiki.archlinux.org/title/SSH_keys)
- [systemd Timers Documentation](https://www.freedesktop.org/software/systemd/man/systemd.timer.html)

---

**Created with ❤️ for secure remote access**

## SSH Key Generation

### Generating Keys for OpenSSH

The standard SSH client that comes with most systems:

```bash
# Generate ED25519 key (recommended - modern and secure)
ssh-keygen -t ed25519 -C "home-tunnel-$(hostname)" -f ~/.ssh/id_rsa

# Or RSA key (if ED25519 not supported)
ssh-keygen -t rsa -b 4096 -C "home-tunnel-$(hostname)" -f ~/.ssh/id_rsa
```

**Key differences:**
- **ED25519**: Modern, fast, small (~600 bytes), best choice
- **RSA-4096**: Widely compatible, larger (~3KB), slower

### Generating Keys for Dropbear

Dropbear uses the same OpenSSH key formats, so you can use the same keys or generate separate ones:

```bash
# Generate key for Dropbear (compatible with OpenSSH)
ssh-keygen -t ed25519 -C "home-tunnel-dropbear" -f ~/.ssh/dropbear_key
```

**Dropbear supports:**
- ✅ ED25519 keys
- ✅ RSA keys  
- ✅ OpenSSH format keys
- ❌ ECDSA (limited support on older versions)

### Using Different Keys

Generate separate keys for different purposes:

```bash
# Key for OpenSSH tunnel
ssh-keygen -t ed25519 -C "home-tunnel-openssh" -f ~/.ssh/id_tunnel_openssh

# Key for Dropbear tunnel
ssh-keygen -t ed25519 -C "home-tunnel-dropbear" -f ~/.ssh/id_tunnel_dropbear
```

Then set in config:
```ini
SSH_KEY=/home/tunnel/.ssh/id_tunnel_openssh
# or
SSH_KEY=/home/tunnel/.ssh/id_tunnel_dropbear
```

### Key Permissions

⚠️ **Critical:** SSH requires strict permissions on keys:

```bash
# Set correct permissions
chmod 600 ~/.ssh/id_rsa
chmod 700 ~/.ssh

# Verify (private key should be -rw-------)
ls -la ~/.ssh/id_rsa
```

### Adding Public Key to Jump Host

```bash
# Method 1: Using ssh-copy-id (easiest)
ssh-copy-id -i ~/.ssh/id_rsa -p 22 tunnel@your.jump.host

# Method 2: Manual paste
cat ~/.ssh/id_rsa.pub
# Copy output to jump host's ~/.ssh/authorized_keys

# Method 3: Pipe to remote
cat ~/.ssh/id_rsa.pub | ssh -p 22 tunnel@your.jump.host \
  "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
```

### Testing Key Authentication

```bash
# Test OpenSSH
ssh -i ~/.ssh/id_rsa -p 22 tunnel@your.jump.host "echo 'Success!'"

# Test Dropbear
dbclient -i ~/.ssh/id_rsa -p 22 tunnel@your.jump.host "echo 'Success!'"

# Verbose output for troubleshooting
ssh -vvv -i ~/.ssh/id_rsa -p 22 tunnel@your.jump.host
```

### Key Security

1. **Use passphrases** - Protect your key with a passphrase
2. **Never share private keys** - Only public keys go on servers
3. **Backup securely** - Encrypt and store backups safely
4. **Separate keys** - Use different keys for different services
5. **Monitor access** - Check logs for unauthorized attempts

See [SETUP_GUIDE.md](SETUP_GUIDE.md#ssh-key-generation-guide) for detailed key generation instructions.


### Only Dropbear Installed (No ssh-keygen)

If you only have `dropbear` installed, here are your options:

**Option 1: Install openssh-client (RECOMMENDED)**
```bash
sudo apt install openssh-client
# Then use ssh-keygen as above
```
**Why?** openssh-client is small (~5-10 MB) and provides `ssh-keygen`.

**Option 2: Generate on another machine**
```bash
# On machine with OpenSSH:
ssh-keygen -t ed25519 -f ~/.ssh/id_rsa

# Copy to Dropbear machine:
scp ~/.ssh/id_rsa dropbear-user@dropbear-host:~/.ssh/id_rsa
```

**Option 3: Pre-existing key**
```bash
# If you already have a key from another system
cp /path/to/existing/key ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa
```

