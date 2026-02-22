# VPS Setup Guide

## Droplet Recommendations

### For Starting (Upgrade as needed)

**DigitalOcean (Recommended for ease of use):**
- **Size**: 4GB RAM / 2 vCPUs ($24/month)
- **Storage**: 80GB SSD
- **OS**: Ubuntu 24.04 LTS (stable, well-documented)
- **Location**: Choose closest to your target audience
- **Backups**: Enable (20% of droplet cost)

**Why 4GB RAM:**
- n8n alone needs ~2GB
- Multiple websites need buffer
- Room for database growth

**Alternative Providers:**
- **Hetzner**: Cheaper, great performance
- **Linode**: Similar pricing to DO
- **AWS Lightsail**: Good if you want AWS ecosystem

---

## Folder Structure

```
/home/deployer/                    # Main deployment user
├── apps/                          # All applications
│   ├── public/                    # Public websites
│   │   ├── site1.com/
│   │   ├── site2.com/
│   │   └── ...
│   ├── private/                   # Private/password-protected sites
│   │   ├── tools.mydomain.com/
│   │   └── admin.mydomain.com/
│   ├── n8n/                       # n8n automation platform
│   └── scripts/                   # Scheduled scripts
│       ├── python/
│       │   └── daily-report.py
│       └── node/
│           └── weekly-cleanup.js
├── repos/                         # Git repositories (if needed)
├── backups/                       # Database backups
├── logs/                          # Application logs
├── secrets/                       # Environment files (restricted permissions)
│   ├── site1.com/
│   │   ├── .env.production
│   │   └── .env.staging
│   └── site2.com/
│       └── .env.production
└── tools/                         # Helper scripts
    └── deploy.sh

/etc/nginx/                        # Nginx configuration
├── sites-available/
│   ├── site1.com
│   ├── site1.com-staging
│   └── private.tools.mydomain.com
└── sites-enabled/

/var/www/                          # Static files served by nginx
├── html/                          # Default fallback
└── (symlinks to /home/deployer/apps/)

/opt/                              # System-wide applications
└── n8n/                           # n8n installation

/var/log/                          # System logs
├── nginx/
├── pm2/                          # Process manager logs
└── scripts/                      # Cron job logs
```

---

## Software Installation Checklist

### 1. System Essentials
```bash
# Update system
sudo apt update && sudo apt upgrade -y
```

**`update`** - Refreshes the package list from repositories. It downloads the latest package information so your system knows what updates are available. It doesn't install anything.

**`upgrade`** - Actually installs available updates for your installed packages. This brings software to newer versions with bug fixes and security patches.

**Why important:**
- Security patches fix vulnerabilities
- Bug fixes improve stability
- New features and compatibility improvements

**How often:**
- **Update**: Before installing any new software, or daily/weekly if you want to stay informed
- **Upgrade**: Weekly to monthly for personal systems; more frequently for production servers (with testing)

**What it affects:**
- Updates system packages, libraries, and installed software
- May require restarts for kernel updates or service reloads
- Could potentially break compatibility with older software (rare but possible)
- Consumes bandwidth and disk space

# Basic tools
```bash
sudo apt install -y curl wget git vim htop tree unzip zip
sudo apt install -y build-essential software-properties-common
```

**What each tool does:**

**File 1 (General utilities):**
- **`curl`** - Command-line tool to transfer data with URLs. Downloads files, tests APIs, fetches web content
- **`wget`** - Another download tool, better for recursive downloads and resuming interrupted downloads
- **`git`** - Version control system. Essential for pulling code from repositories
- **`vim`** - Text editor. Edit configuration files directly on the server
- **`htop`** - Interactive process viewer. See what's running, CPU/memory usage, kill processes
- **`tree`** - Display directory structure in a tree-like format. Useful for exploring the filesystem
- **`unzip`** / **`zip`** - Compress and decompress zip archives

**File 2 (Development tools):**
- **`build-essential`** - Meta-package including GCC compiler, make, and other tools needed to compile software from source
- **`software-properties-common`** - Manage software repositories and PPAs. Needed for adding third-party repos like NodeSource

**Why these are important:**
- **curl/wget**: Download installation scripts, fetch files, test endpoints
- **git**: Pull your application code from GitHub
- **vim**: Edit nginx configs, environment files, troubleshoot issues
- **htop**: Monitor server health, identify resource hogs
- **build-essential**: Compile native Node.js modules, Python packages with C extensions

## User Management (Don't Use Root!)

### Why Create a Separate User?

**The Problem with Root:**

Root is the superuser with unlimited power. One typo can destroy your entire server:

```bash
# This typo would delete your ENTIRE server:
rm -rf /var/www/   # Oops, typed: rm -rf / var/www/  (space after /)
# Result: Deletes everything from root directory!
```

**With root, you can accidentally:**
- Delete critical system files
- Change permissions that break the OS
- Run malicious scripts that infect the system
- No "undo" button - root bypasses all protections

**Why Use a Regular User (`deployer`):**

1. **Mistake Protection**
   - Regular user can't delete system files
   - Can't accidentally change system permissions
   - Mistakes are limited to user's home directory

2. **Security**
   - Apps run with limited permissions (can't access system files)
   - If an app is compromised, damage is contained
   - Attacker can't install system-wide malware

3. **Principle of Least Privilege**
   - Only use sudo when absolutely necessary
   - Daily tasks (deploying apps, editing configs) don't need root
   - System changes require explicit `sudo` command

4. **Accountability**
   - System logs show which user performed actions
   - Track who made changes and when

5. **SSH Security**
   - Can disable root SSH login entirely
   - Brute-force attacks on "root" are common
   - Much harder to guess both username AND password

**Real Example:**

```bash
# As deployer user (safe):
deployer@vps:~$ rm -rf /var/www/myapp   # Works, deletes your app only

# Same command as root (dangerous):
root@vps:~# rm -rf /var/www/myapp       # Typo risk: could delete system

# System protection as deployer:
deployer@vps:~$ rm -rf /etc/nginx       # ERROR: Permission denied (saved!)
root@vps:~# rm -rf /etc/nginx           # Works... server broken
```

**Best Practice:**
- Use `deployer` user for 99% of operations
- Only switch to root for system-level changes (rare)
- Set up SSH keys for deployer, disable root SSH
- Use `sudo` when you need elevated permissions

### Creating the Deployer User

```bash
# As root (only time you need root):
sudo adduser deployer
sudo usermod -aG sudo deployer

# Switch to deployer user
su - deployer

# Now you can use sudo when needed
deployer@vps:~$ sudo apt update
deployer@vps:~$ sudo systemctl restart nginx
```

### Logging in as Deployer via SSH

After creating the user, you can log in directly:

```bash
# From your local machine
ssh deployer@your-server-ip

# Example:
ssh deployer@192.168.1.100
```

**First time only - set up SSH key authentication:**

1. **Copy your SSH public key to the server:**
   ```bash
   # From your LOCAL machine
   ssh-copy-id deployer@your-server-ip
   ```

2. **Or manually add the key:**
   ```bash
   # On the server, as deployer:
   mkdir -p ~/.ssh
   chmod 700 ~/.ssh
   
   # Add your public key
   nano ~/.ssh/authorized_keys
   # Paste your public key here
   
   chmod 600 ~/.ssh/authorized_keys
   ```

3. **Test key authentication:**
   ```bash
   # Should log in without password
   ssh deployer@your-server-ip
   ```

### When to Use Root vs Deployer

**Use DEPLOYER user for (99% of tasks):**
- Deploying applications
- Editing nginx configs (`sudo nano /etc/nginx/...`)
- Managing PM2 processes
- Running git commands
- Installing npm packages
- Running Python scripts
- Viewing logs
- Restarting services (`sudo systemctl restart nginx`)
- Installing software (`sudo apt install ...`)

**Use ROOT only for (rare system tasks):**
- Creating/deleting users
- Modifying system-wide SSH config (`/etc/ssh/sshd_config`)
- Changing system permissions on system directories
- Installing system kernels or drivers
- Recovering from serious system issues
- Initial server setup (before deployer exists)

**Switching between users:**

```bash
# If logged in as deployer, need to do something as root:
su -           # Switch to root (will ask for root password)
sudo -i        # Alternative: become root with sudo

# When done, exit back to deployer:
exit

# If logged in as root, switch to deployer:
su - deployer
```

**Warning Signs You're Using Root Unnecessarily:**
- You're editing files in `/var/www/` (deployer should own these)
- You're running `npm install` or `pip install` without `sudo`
- You're in `/home/deployer` directory as root
- You see `root@hostname` in your prompt during normal work

## Security Setup

After basic tools, configure security before exposing your server to the internet.

### Hetzner Cloud Firewall vs Server Firewall

**Use BOTH** for defense in depth:

**Hetzner Cloud Firewall (Console):**
- Network-level filtering before traffic reaches your server
- Protects against DDoS and network floods
- **Configure**: Allow ports 22 (SSH), 80 (HTTP), 443 (HTTPS)
- **Pros**: Zero server resources, stops attacks before they reach you
- **Cons**: Can't see detailed logs, less granular control

**UFW (Server-level):**
- Runs on your server, sees all traffic
- Can block specific IPs, create complex rules
- **Enable**: After setting up Hetzner firewall
- **Pros**: More control, detailed logging, blocks malicious IPs dynamically
- **Cons**: Uses minimal CPU/memory, traffic reaches server first

### Why Both Are Important

1. **Hetzner firewall** = First line of defense (stops bulk attacks)
2. **UFW** = Second line (granular control, dynamic blocking)
3. **Fail2ban** = Third line (brute-force protection, intelligent banning)

**Setup Order:**
1. Configure Hetzner Cloud Firewall in console first
2. Install and configure UFW on server
3. Install and enable fail2ban

This layered approach means if one fails or is misconfigured, others still protect you.

### Hetzner Cloud Firewall Configuration

**Protocol Types:**
- **TCP** - Connection-based (websites, SSH, databases) - Use for most services
- **UDP** - Connectionless (DNS, streaming) - Not needed for basic web server
- **ICMP** - Network diagnostics (ping) - Good for health checks and monitoring
- **GRE/ESP** - VPN protocols - Skip unless using VPN

**Recommended Inbound Rules:**

| Direction | Protocol | Port | Description |
|-----------|----------|------|-------------|
| Inbound | TCP | 22 | SSH - Remote server access (required) |
| Inbound | TCP | 80 | HTTP - Websites (redirects to HTTPS) |
| Inbound | TCP | 443 | HTTPS - Secure websites |
| Inbound | ICMP | Any | Ping - For monitoring and health checks |

**Optional Rules (add later when needed):**
- **TCP 5678** - n8n web interface (when you set up n8n)
- **TCP 3000-3010** - Range for development/testing apps

**Outbound Rules:**
- Leave as "Allow all" (default) - Your server needs to reach package repositories, APIs, etc.

**How to Configure:**
1. Go to Hetzner Cloud Console → Your Project → Firewalls
2. Create new firewall or edit existing
3. Add inbound rules (table above)
4. Apply firewall to your server

**Port Format:**
- Single port: `22`
- Port range: `3000-3010`
- Leave empty or use `any` for ICMP

**Important:** Configure Hetzner firewall BEFORE enabling UFW on the server, or you might lock yourself out.

### Security Tools Installation
```bash
sudo apt install -y ufw fail2ban
```

### What These Do

**`ufw`** (Uncomplicated Firewall) - Controls network traffic at the server level
- Blocks all incoming traffic by default
- Allows only whitelisted ports (SSH, HTTP, HTTPS)
- Prevents attackers from reaching services on random ports
- **Install on server**: Yes, always. Even if using cloud firewall.

**`fail2ban`** - Intrusion prevention system
- Monitors authentication logs (SSH, nginx, etc.)
- Automatically bans IP addresses after multiple failed login attempts
- Protects against brute-force attacks on SSH and web applications
- **Critical for**: SSH protection, stopping automated attacks

### UFW Configuration

UFW needs configuration before enabling. Use port numbers (works even before nginx is installed):

```bash
sudo ufw allow 22/tcp       # SSH - remote access (required!)
sudo ufw allow 80/tcp       # HTTP - websites
sudo ufw allow 443/tcp      # HTTPS - secure websites
sudo ufw --force enable     # Turn on the firewall
```

**Why these are required:**
- **Port 22 (SSH)**: Without this, you'll lock yourself out of your server
- **Port 80 (HTTP)** and **Port 443 (HTTPS)**: Allows web traffic for your websites

**Note:** Using port numbers instead of profile names (`'Nginx Full'`) avoids dependency issues - nginx profiles only exist after nginx is installed.

**Additional useful commands:**

```bash
# Check current rules before enabling
sudo ufw status verbose

# Allow specific ports for apps
sudo ufw allow 5678        # n8n web interface
sudo ufw allow 3000        # Next.js dev server

# Block specific IPs
sudo ufw deny from 192.168.1.100

# Delete a rule
sudo ufw delete allow 3000
```

**Important:** Always configure rules BEFORE enabling UFW with `sudo ufw enable`, or you may lose SSH access.


### 3. Node.js & Python Environment
See [03_RUNTIMES.md](03_RUNTIMES.md) for detailed setup instructions.

- [ ] **Node.js 24 LTS** - Runtime for Next.js, React apps
- [ ] **PM2** - Process manager for Node.js apps
- [ ] **Python 3.12** - For scripts and backend services
- [ ] **pip & virtualenv** - Python package management

### 4. Web Server & SSL
See [04_WEB_SERVER.md](04_WEB_SERVER.md) for complete nginx and SSL setup.

- [ ] **Nginx** - Reverse proxy and static file serving
- [ ] **Certbot** - Let's Encrypt SSL certificates


### 5. Database (if needed locally)
- [ ] **SQLite3** - For small databases
- [ ] **PostgreSQL** - Alternative to SQLite
- [ ] **Redis** - Caching and session storage

### 6. Automation & Scheduling
- [ ] **n8n** - Workflow automation
- [ ] **Cron** - Built-in, for scheduled scripts

### 7. Security (Already configured above)
- [x] **UFW** - Firewall (installed in Security Setup section)
- [x] **Fail2ban** - Brute force protection (installed in Security Setup section)
- [ ] **Docker** (optional) - Containerization

### 8. Deployment Tools
- [ ] **GitHub CLI (gh)** - For repository management
- [ ] **Webhook server** - For auto-deployment (or use GitHub Actions)

---

## Quick Install Commands

```bash
# After fresh Ubuntu 22.04 install:

# 1. Create deployer user
sudo adduser deployer
sudo usermod -aG sudo deployer

# 2. Install Node.js 24 LTS (see 03_RUNTIMES.md for full guide)
curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
sudo apt install -y nodejs

# 3. Install PM2 globally
sudo npm install -g pm2@latest

# 4. Install Python 3.12 (Ubuntu 24.04 has it pre-installed)
sudo apt install -y python3-pip python3-venv python3.12-venv

# 5. Install SQLite (usually pre-installed)
sudo apt install -y sqlite3

# 6. Install n8n (as deployer user, not root)
sudo npm install n8n -g

# 7. Enable UFW firewall (configure Hetzner firewall first)
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable

# 8. Enable fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

---

## Next Steps

1. **SSH Key Setup**: Complete [01_SSH_SETUP.md](01_SSH_SETUP.md)
2. **DNS Setup**: Point your domains to your VPS IP address
3. **Node.js & Python Setup**: Follow [03_RUNTIMES.md](03_RUNTIMES.md) for detailed environment configuration
4. **Web Server Setup**: Follow [04_WEB_SERVER.md](04_WEB_SERVER.md) to configure nginx, SSL, and host your websites
5. **GitHub Webhooks**: Configure auto-deployment
6. **Secret Management**: Set up `/home/deployer/secrets/` with restricted permissions
7. **Backup Strategy**: Set up automated backups
8. **Monitoring**: Set up log monitoring and alerts

## Estimated Monthly Costs

- **DigitalOcean 4GB**: $24/month
- **Backups (20%)**: $4.80/month
- **Total**: ~$29/month

*Upgrade to 8GB ($48/month) when hosting 10+ sites or heavy n8n usage*
