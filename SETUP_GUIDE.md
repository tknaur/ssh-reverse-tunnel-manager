# SSH Reverse Tunnel Setup Guide

## Overview
This setup allows you to access your home computer's SSH server from the internet via a reverse tunnel through a jump host.

**Tunnel Architecture:**
```
Your Home Computer (SSH on port 22)
         ↓
SSH Reverse Tunnel (:22 → jump_host:TUNNEL_PORT)
         ↓
jump_host (remote server with SSH)
         ↓
Internet Users (connect to jump_host:TUNNEL_PORT)
```

## Prerequisites

1. **Debian-based system** (Ubuntu, Raspberry Pi OS, etc.)
2. **SSH server running** on your home computer (port 22)
3. **Access to jump host** with a user account (e.g., `tunnel`)
4. **SSH key authentication** configured (recommended)

## Important: Jump Host Configuration

⚠️ **Critical Step:** Your jump host must allow reverse tunnel connections to be accessible from the internet.

SSH on your jump host must have `GatewayPorts` enabled:

```bash
# SSH to your jump host
ssh tunnel@your.jump.host

# Edit SSH config
sudo nano /etc/ssh/sshd_config

# Add or verify this line exists:
GatewayPorts yes

# Save and reload SSH
sudo systemctl reload sshd

# Verify it's configured
grep GatewayPorts /etc/ssh/sshd_config
```

**Why?** By default, SSH tunnel ports only listen on localhost (127.0.0.1). With `GatewayPorts yes`, the tunnel port will listen on all interfaces (0.0.0.0) making it accessible from the internet.

## SSH Key Generation Guide

Before setting up the tunnel, you need to generate SSH keys. This section covers key generation for both OpenSSH and Dropbear clients.

### For OpenSSH (Standard SSH Client)

**Generate a new ED25519 key (recommended - secure and efficient):**

```bash
# Generate new key
ssh-keygen -t ed25519 -C "home-tunnel-$(hostname)" -f ~/.ssh/id_rsa

# Prompts:
# Enter passphrase (optional, press Enter for no passphrase)
# Enter same passphrase again
```

**Or use RSA key (older but widely compatible):**

```bash
# Generate 4096-bit RSA key
ssh-keygen -t rsa -b 4096 -C "home-tunnel-$(hostname)" -f ~/.ssh/id_rsa
```

**Key types explained:**
- **ED25519** - Modern, secure, smaller file size (~600 bytes), fast
- **RSA 4096** - Older but widely supported, larger file (~3KB), slower

**Recommended:** Use ED25519 unless your jump host is very old.

### For Dropbear (Lightweight SSH Client)

Dropbear uses the same OpenSSH key formats, so you can use the same keys generated above. However, Dropbear may have specific requirements:

**Generate key compatible with Dropbear:**

```bash
# Generate ED25519 key
ssh-keygen -t ed25519 -C "home-tunnel-dropbear" -f ~/.ssh/dropbear_key

# Or RSA key
ssh-keygen -t rsa -b 4096 -C "home-tunnel-dropbear" -f ~/.ssh/dropbear_key
```

**Dropbear compatibility:**
- ✅ ED25519 keys - Full support
- ✅ RSA keys - Full support
- ✅ OpenSSH keys - Full support (since Dropbear 2016+)
- ❌ ECDSA keys - Limited support on older versions

### When Only Dropbear is Installed (No ssh-keygen)

If you have only `dropbear` and `dbclient` installed (no `openssh-client`), you have several options:

#### Option 1: Install openssh-client (Recommended)

```bash
# Debian/Raspberry Pi OS
sudo apt install openssh-client

# Then use ssh-keygen as above
ssh-keygen -t ed25519 -C "home-tunnel" -f ~/.ssh/id_rsa
```

**Why?** `openssh-client` provides `ssh-keygen` which is the easiest way to generate keys. It's small and adds minimal overhead.

#### Option 2: Generate on Another Machine

Generate your key on a machine with `ssh-keygen` available, then copy it to your home machine:

```bash
# On machine with OpenSSH installed:
ssh-keygen -t ed25519 -C "home-tunnel-dropbear" -f ~/.ssh/id_rsa

# Copy to your Dropbear machine
scp ~/.ssh/id_rsa user@dropbear-machine:~/.ssh/id_rsa
scp ~/.ssh/id_rsa.pub user@dropbear-machine:~/.ssh/id_rsa.pub

# On the Dropbear machine:
chmod 600 ~/.ssh/id_rsa
chmod 700 ~/.ssh
```

#### Option 3: Use dropbear Key Tools

Dropbear includes `dropbearkey` but it's primarily for server keys. However, you can use it with conversion:

```bash
# Check if dropbearkey is available
which dropbearkey

# Generate Dropbear format key
dropbearkey -t ed25519 -f ~/.ssh/id_dropbear -s 4096

# Convert to OpenSSH format (if you have ssh-keygen installed)
# This requires ssh-keygen, so this is circular...
```

**Note:** This approach requires `dropbear-convert` or manual conversion, which is more complex. **Option 1 or 2 is recommended.**

#### Option 4: Use Pre-shared Keys or Passwords

If key generation is problematic, you can temporarily use password authentication:

```bash
# Connect with password (less secure, but works)
dbclient -p 22 tunnel@your.jump.host

# After connecting, you can copy your public key to authorized_keys
# Then disable password auth
```

**⚠️ Note:** This is less secure and should be temporary.

### Minimal Setup with Only Dropbear

If you absolutely cannot install `openssh-client`, here's the minimal workflow:

```bash
# 1. Install dropbear package (if not already installed)
sudo apt install dropbear

# 2. Install openssh-client for ssh-keygen (very small)
sudo apt install openssh-client

# 3. Generate key
ssh-keygen -t ed25519 -C "home-tunnel" -f ~/.ssh/id_rsa

# 4. Add public key to jump host
cat ~/.ssh/id_rsa.pub | ssh -p 22 tunnel@your.jump.host \
  "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"

# 5. Test with dropbear
dbclient -i ~/.ssh/id_rsa -p 22 tunnel@your.jump.host "echo Success"
```

**Package sizes (minimal overhead):**
- `openssh-client`: ~5-10 MB (very small)
- `dropbear`: ~1-2 MB

Installing both `openssh-client` + `dropbear` still uses less space than `openssh-server`!

### Using Different Keys for Different Clients

You can generate separate keys for different purposes:

```bash
# Primary key for OpenSSH
ssh-keygen -t ed25519 -C "home-tunnel-openssh" -f ~/.ssh/id_tunnel_openssh

# Backup key for Dropbear
ssh-keygen -t ed25519 -C "home-tunnel-dropbear" -f ~/.ssh/id_tunnel_dropbear

# List your keys
ls -la ~/.ssh/id_tunnel_*
```

Then specify the key in your configuration:

```bash
# For OpenSSH in config
SSH_KEY=/home/tunnel/.ssh/id_tunnel_openssh

# Or for Dropbear
SSH_KEY=/home/tunnel/.ssh/id_tunnel_dropbear
```

### Key Permissions

⚠️ **Critical:** Keys must have proper permissions or SSH will reject them.

```bash
# Set correct permissions on key
chmod 600 ~/.ssh/id_rsa

# Set correct permissions on SSH directory
chmod 700 ~/.ssh

# Verify permissions
ls -la ~/.ssh/
# Should show: -rw------- (600) for the private key
# Should show: drwx------ (700) for the directory
```

### Adding Public Key to Jump Host

After generating your key, add the public key to your jump host's `authorized_keys`:

```bash
# Option 1: Using ssh-copy-id (easiest)
ssh-copy-id -i ~/.ssh/id_rsa -p 22 tunnel@your.jump.host

# Option 2: Manual - cat and paste
cat ~/.ssh/id_rsa.pub
# Copy the output and add to jump host's ~/.ssh/authorized_keys

# Option 3: Pipe to remote server
cat ~/.ssh/id_rsa.pub | ssh -p 22 tunnel@your.jump.host "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
```

### Testing SSH Key Authentication

Verify that key-based authentication works:

```bash
# Test OpenSSH key
ssh -i ~/.ssh/id_rsa -p 22 tunnel@your.jump.host "echo 'Success!'"

# Test Dropbear key
dbclient -i ~/.ssh/id_rsa -p 22 tunnel@your.jump.host "echo 'Success!'"

# Test with verbose output (troubleshooting)
ssh -vvv -i ~/.ssh/id_rsa -p 22 tunnel@your.jump.host
```

### Key Security Best Practices

1. **Use strong passphrases** when generating keys
2. **Never share private keys** - only public keys go on servers
3. **Back up keys securely** - store in secure location
4. **Rotate keys periodically** - especially if key is used widely
5. **Use different keys for different purposes** - separate keys for home, work, services
6. **Monitor key usage** - check syslog for unauthorized access attempts

Example - Secure key backup:

```bash
# Encrypt and backup your private key
tar czf - ~/.ssh/id_rsa | gpg --symmetric --output ~/ssh-backup.tar.gz.gpg

# Restore from backup
gpg --decrypt ~/ssh-backup.tar.gz.gpg | tar xz
```

## Installation Steps

### Step 1: Set Up SSH Key Authentication

On your home computer (as the user who will run the tunnel, e.g., `tunnel`):

```bash
# Generate SSH key if you don't have one
ssh-keygen -t ed25519 -C "home-tunnel-$(hostname)" -f ~/.ssh/id_rsa

# Test connection to jump host
ssh -p 22 tunnel@your.jump.host "echo 'Connection successful'"

# Ensure correct permissions
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub
```

If key-based authentication is not yet set up on the jump host:
1. Add your public key to `~/.ssh/authorized_keys` on the jump host
2. Or configure password-based SSH first and then add your key

### Step 2: Install the Script

```bash
# Copy script to system location
sudo cp ssh-reverse-tunnel.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/ssh-reverse-tunnel.sh

# Copy monitoring script
sudo cp monitor-tunnel.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/monitor-tunnel.sh

# Copy configuration file
sudo cp ssh-reverse-tunnel.conf /etc/
```

### Step 3: Install as Systemd Service

```bash
# Copy service files
sudo cp ssh-reverse-tunnel.service /etc/systemd/system/
sudo cp ssh-reverse-tunnel-monitor.service /etc/systemd/system/
sudo cp ssh-reverse-tunnel-monitor.timer /etc/systemd/system/

# Reload systemd daemon
sudo systemctl daemon-reload
```

### Step 4: Configure Your Settings

Edit the configuration file with your actual values:

```bash
sudo nano /etc/ssh-reverse-tunnel.conf
```

Replace the placeholder values:

```ini
# Replace "your.jump.host" with your actual jump host hostname or IP
REMOTE_HOST=your.jump.host

# Replace "tunnel" with your actual username on the jump host
REMOTE_USER=tunnel

# SSH port on jump host (usually 22, unless custom)
REMOTE_PORT=22

# Port on jump host that will forward to your home SSH (can be any unused port)
TUNNEL_PORT=2222

# Local port to forward (usually 22 for SSH)
LOCAL_PORT=22

# Path to your SSH private key
SSH_KEY=/home/tunnel/.ssh/id_rsa
```

**Example real configuration:**
```ini
REMOTE_HOST=vps.example.com
REMOTE_USER=tunnel
REMOTE_PORT=22
TUNNEL_PORT=2222
LOCAL_PORT=22
SSH_KEY=/home/tunnel/.ssh/id_rsa
```

### Step 5: Enable and Start Services

```bash
# Enable and start the tunnel service
sudo systemctl enable ssh-reverse-tunnel
sudo systemctl start ssh-reverse-tunnel

# Enable and start the monitoring timer (for auto-restart)
sudo systemctl enable ssh-reverse-tunnel-monitor.timer
sudo systemctl start ssh-reverse-tunnel-monitor.timer

# Check status
sudo systemctl status ssh-reverse-tunnel
sudo systemctl status ssh-reverse-tunnel-monitor.timer
```

### Step 6: Verify Tunnel is Working

```bash
# Check if service is running
sudo systemctl status ssh-reverse-tunnel

# Check recent logs
sudo journalctl -u ssh-reverse-tunnel -n 20

# Monitor logs in real-time
sudo journalctl -u ssh-reverse-tunnel -f

# From another machine, test SSH connection through tunnel
# Replace with your actual values
ssh -p 2222 your_username@your.jump.host
```

## Configuration

### Via Configuration File

Edit `/etc/ssh-reverse-tunnel.conf`:

```bash
sudo nano /etc/ssh-reverse-tunnel.conf
```

Example with placeholder explanations:
```ini
# Your jump host's hostname or IP address
# Examples: vps.example.com, 192.168.1.100, cloud-server.provider.com
REMOTE_HOST=your.jump.host

# Username on the jump host
# This user must have SSH access enabled
REMOTE_USER=tunnel

# SSH port on the jump host (standard is 22)
REMOTE_PORT=22

# Port on jump host that will forward back to your home SSH
# Should be an unused port (avoid 22, 80, 443, etc)
# This is the port you'll connect to: ssh -p TUNNEL_PORT user@jump_host
TUNNEL_PORT=2222

# Local port on your home computer to forward
# Usually 22 for SSH, or 80/443 for web services
LOCAL_PORT=22

# Path to your SSH private key for authentication
# Must be readable by the service user
SSH_KEY=/home/tunnel/.ssh/id_rsa

# Optional: SSH client to use ('openssh' or 'dropbear')
# For resource-constrained devices, use 'dropbear'
SSH_CLIENT=openssh

# Optional: Dropbear options (only used if SSH_CLIENT=dropbear)
DROPBEAR_OPTS=-y
```

### Via Environment Variables

```bash
# Override configuration temporarily
REMOTE_HOST=custom.host TUNNEL_PORT=3333 /usr/local/bin/ssh-reverse-tunnel.sh start

# Or use custom SSH key
SSH_KEY=/path/to/custom/key /usr/local/bin/ssh-reverse-tunnel.sh start
```

### Via Systemd Service

```bash
# Edit the service file
sudo systemctl edit ssh-reverse-tunnel

# Add or modify Environment lines:
[Service]
Environment="REMOTE_HOST=your.jump.host"
Environment="TUNNEL_PORT=2222"
Environment="SSH_KEY=/home/tunnel/.ssh/id_rsa"

# Save and reload
sudo systemctl daemon-reload
sudo systemctl restart ssh-reverse-tunnel
```

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

# Enable debug mode to see SSH errors
DEBUG=1 /usr/local/bin/ssh-reverse-tunnel.sh start
```

## Monitoring

### Check Tunnel Health

```bash
# View service status
sudo systemctl status ssh-reverse-tunnel

# View recent logs
sudo journalctl -u ssh-reverse-tunnel --since "10 minutes ago"

# Monitor in real-time
sudo journalctl -u ssh-reverse-tunnel -f
```

### Monitor Health Check Status

The monitoring script automatically checks tunnel health every minute:

```bash
# View monitor timer status
sudo systemctl status ssh-reverse-tunnel-monitor.timer

# View monitor logs
sudo journalctl -u ssh-reverse-tunnel-monitor.service -f

# Check next scheduled run
systemctl list-timers ssh-reverse-tunnel-monitor.timer
```

### Disable Auto-Restart

If you want to disable automatic restarts:

```bash
# Stop the monitoring timer
sudo systemctl stop ssh-reverse-tunnel-monitor.timer
sudo systemctl disable ssh-reverse-tunnel-monitor.timer

# The tunnel will still run, but won't auto-restart if it fails
```

## Troubleshooting

### Service won't start

```bash
# Check service status and error messages
sudo systemctl status ssh-reverse-tunnel
sudo journalctl -u ssh-reverse-tunnel -n 50

# Check if SSH key is readable
ls -la ~/.ssh/id_rsa

# Verify SSH key permissions (must be 600)
chmod 600 ~/.ssh/id_rsa
```

### Can't connect through tunnel from internet

**First, verify tunnel is listening on jump host:**

```bash
# SSH to your jump host and check
ssh tunnel@your.jump.host "netstat -tulnp | grep LISTEN"

# Look for the port specified in TUNNEL_PORT (e.g., 2222)
# Should show: tcp 0 0 0.0.0.0:2222 0.0.0.0:* LISTEN
```

**If port is only listening on 127.0.0.1, you need to:**

```bash
# SSH to jump host and enable GatewayPorts
ssh tunnel@your.jump.host

# Edit SSH config
sudo nano /etc/ssh/sshd_config

# Ensure this line exists and is not commented:
GatewayPorts yes

# Reload SSH
sudo systemctl reload sshd

# Verify
grep GatewayPorts /etc/ssh/sshd_config
```

**Then restart your tunnel:**
```bash
sudo systemctl restart ssh-reverse-tunnel
```

### SSH key permission issues

```bash
# Ensure proper key permissions (must be 600)
chmod 600 /home/tunnel/.ssh/id_rsa

# Ensure proper home directory permissions
chmod 700 /home/tunnel/.ssh
chmod 700 /home/tunnel

# If running as a service, ensure the user owns the key
sudo chown tunnel:tunnel /home/tunnel/.ssh/id_rsa
```

### Connection timeout

Check that:
1. Jump host SSH port is accessible (usually 22)
2. Local SSH server is running: `sudo systemctl status ssh`
3. No firewall blocking connections
4. Configuration has correct REMOTE_HOST and REMOTE_PORT

### Test manually with debug output

```bash
# Run with debug mode to see actual SSH errors
DEBUG=1 /usr/local/bin/ssh-reverse-tunnel.sh start

# This will show detailed SSH connection output
```

### Verify direct SSH connection

Test if you can manually SSH to the jump host:

```bash
# Replace with your actual values
ssh -vvv -p 22 tunnel@your.jump.host

# Should succeed if everything is configured correctly
```

## Security Considerations

1. **SSH Key Protection**: Keep your private key secure with proper permissions (600)
2. **Port Access**: The tunnel port on the jump host is publicly accessible - restrict access if needed:
   ```bash
   # On jump host, use firewall to restrict access
   sudo ufw allow from 192.168.1.0/24 to any port 2222  # Only from your IP range
   ```
3. **Network Monitoring**: Monitor active connections to detect unauthorized access
4. **Regular Updates**: Keep your system and SSH updated
5. **Log Monitoring**: Regularly check logs for failed connection attempts

## Advanced Usage

### Custom SSH Key for Service

If using a different SSH key:

```bash
sudo nano /etc/systemd/system/ssh-reverse-tunnel.service
# Change: Environment="SSH_KEY=/path/to/custom/key"
sudo systemctl daemon-reload
sudo systemctl restart ssh-reverse-tunnel
```

### Running Multiple Tunnels

Create separate service files for multiple tunnels:

```bash
# Create second service
sudo cp ssh-reverse-tunnel.service /etc/systemd/system/ssh-reverse-tunnel-backup.service

# Edit the second service
sudo nano /etc/systemd/system/ssh-reverse-tunnel-backup.service

# Change:
# Description=SSH Reverse Tunnel (Backup)
# Environment="TUNNEL_PORT=3333"
# Environment="PID_FILE=/var/run/ssh-reverse-tunnel-backup.pid"

sudo systemctl daemon-reload
sudo systemctl enable ssh-reverse-tunnel-backup
sudo systemctl start ssh-reverse-tunnel-backup
```

### Using Dropbear SSH Client

For resource-constrained devices like Raspberry Pi:

**Installation:**
```bash
sudo apt install dropbear
```

**Usage:**
```bash
# Edit configuration
sudo nano /etc/ssh-reverse-tunnel.conf

# Change to:
SSH_CLIENT=dropbear
DROPBEAR_OPTS=-y

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart ssh-reverse-tunnel
```

**Memory comparison:**
- OpenSSH: ~10-20 MB
- Dropbear: ~1-2 MB

Perfect for Raspberry Pi and IoT devices.

## Uninstallation

```bash
# Stop the service
sudo systemctl stop ssh-reverse-tunnel
sudo systemctl stop ssh-reverse-tunnel-monitor.timer

# Disable from boot
sudo systemctl disable ssh-reverse-tunnel
sudo systemctl disable ssh-reverse-tunnel-monitor.timer

# Remove service files
sudo rm /etc/systemd/system/ssh-reverse-tunnel.service
sudo rm /etc/systemd/system/ssh-reverse-tunnel-monitor.service
sudo rm /etc/systemd/system/ssh-reverse-tunnel-monitor.timer

# Remove scripts
sudo rm /usr/local/bin/ssh-reverse-tunnel.sh
sudo rm /usr/local/bin/monitor-tunnel.sh

# Remove config (optional)
sudo rm /etc/ssh-reverse-tunnel.conf

# Reload systemd
sudo systemctl daemon-reload
```

## Getting Help

1. Check the [README.md](README.md) for overview and features
2. Review script comments for implementation details
3. Check systemd journal logs: `sudo journalctl -u ssh-reverse-tunnel -f`
4. Enable debug mode: `DEBUG=1 ssh-reverse-tunnel.sh start`
5. Test direct SSH connection: `ssh -vvv -p 22 tunnel@your.jump.host`

---

**Created with ❤️ for secure remote access**
