# Node.js and Python Environment Setup

Complete guide for setting up Node.js and Python environments on Ubuntu 24.04 LTS VPS.

---

## Node.js Setup

### Latest Stable Version
**Node.js 24.x LTS** (Long Term Support)

**Why LTS?**
- Stable and production-ready
- 30 months of support
- Security patches and bug fixes
- Recommended for production servers

---

### Installation

#### Method 1: NodeSource Repository (Recommended for production)

Best for servers running a single Node.js version:

```bash
# Install Node.js 24.x LTS
curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
sudo apt install -y nodejs

# Verify installation
node --version    # Should show v24.x.x
npm --version     # Should show 11.x.x
```

**What this does:**
- Adds the official NodeSource repository
- Installs Node.js 24.x and npm
- Sets up the Node.js binary in your PATH

#### Method 2: Using NVM (Node Version Manager)

Useful for development or when you need multiple Node.js versions:

```bash
# Download and install NVM
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash

# Load NVM (instead of restarting the shell)
\export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Download and install Node.js:
nvm install 24

# Verify the Node.js version:
node -v # Should print "v24.x.x"

# Verify npm version:
npm -v  # Should print "11.x.x"

# Set as default
nvm alias default 24
```

**When to use NVM:**
- Multiple projects need different Node versions
- Testing apps across Node versions
- Development environments

**When NOT to use NVM on production:**
- Single application servers (adds complexity)
- Use Method 1 for production VPS

**When to use NVM:**
- Multiple projects need different Node versions
- Testing apps across Node versions
- Development environments

**When NOT to use NVM on production:**
- Single application servers (adds complexity)
- Use Method 1 for production VPS

---

### Essential Global Packages

```bash
# PM2 - Process manager for Node.js apps
sudo npm install -g pm2@latest

# Yarn - Alternative package manager (optional)
sudo npm install -g yarn
```

### Why PM2 is Essential for Production

**Without PM2 (just running `node app.js`):**
- App crashes when it encounters an error → **site goes down**
- You close SSH terminal → **app stops running**
- Server reboots → **app doesn't restart automatically**
- No way to monitor if app is healthy
- High CPU/memory usage kills the process → **no recovery**
- Can't run multiple instances to handle more traffic

**With PM2:**
- ✅ **Auto-restart** - App crashes? PM2 restarts it immediately
- ✅ **Background process** - Runs even after you disconnect SSH
- ✅ **Boot persistence** - Auto-starts apps when server reboots
- ✅ **Monitoring** - See CPU, memory, uptime in real-time
- ✅ **Log management** - Centralized logs for debugging
- ✅ **Cluster mode** - Run multiple instances on all CPU cores
- ✅ **Zero-downtime deploys** - Reload without stopping the service

**Real-world scenario:**
Your Next.js app has a bug that crashes it at 3 AM. Without PM2, your site is down until you manually restart it. With PM2, it's back online in seconds, and you check the logs in the morning to fix the bug.

**PM2 Commands:**
```bash
# Start an app
pm2 start app.js
pm2 start npm --name "myapp" -- start

# Manage processes
pm2 list                    # See all running apps
pm2 stop myapp             # Stop specific app
pm2 restart myapp          # Restart app
pm2 delete myapp           # Remove from PM2
pm2 logs myapp             # View logs
pm2 monit                  # Real-time monitoring

# Auto-start on boot
pm2 startup
pm2 save
```

**Practical Example - Next.js App:**
```bash
# Navigate to your app directory
cd /home/deployer/apps/my-nextjs-app

# Build the app first
npm run build

# Start with PM2 (production mode)
pm2 start npm --name "my-nextjs-app" -- start

# Check it's running
pm2 list

# View logs
pm2 logs my-nextjs-app

# Save PM2 config to auto-start on reboot
pm2 save
pm2 startup

# Later, deploy an update:
pm2 restart my-nextjs-app
```

**ECOSYSTEM FILE (advanced):**
For complex apps, create `ecosystem.config.js`:
```javascript
module.exports = {
  apps: [{
    name: 'my-nextjs-app',
    cwd: '/home/deployer/apps/my-nextjs-app',
    script: 'npm',
    args: 'start',
    instances: 'max',        // Use all CPU cores
    exec_mode: 'cluster',    // Enable cluster mode
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    log_file: '/home/deployer/logs/my-nextjs-app.log',
    error_file: '/home/deployer/logs/my-nextjs-app-error.log',
    out_file: '/home/deployer/logs/my-nextjs-app-out.log',
    max_memory_restart: '500M',  // Restart if memory > 500MB
    restart_delay: 3000,         // Wait 3s before restarting
    max_restarts: 5,             // Stop after 5 crashes in 15s
    min_uptime: '10s'            // Must run 10s to be "started"
  }]
};
```

Then start with: `pm2 start ecosystem.config.js`

---

### Common Issues & Solutions

**1. Permission denied when installing global packages**
```bash
# DON'T use sudo with npm install (security risk)
# Instead, fix permissions:
mkdir ~/.npm-global
npm config set prefix '~/.npm-global'
echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.bashrc
source ~/.bashrc
```

**2. Node version shows old version after upgrade**
```bash
# Clear npm cache
sudo npm cache clean -f

# Reinstall Node.js
curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
sudo apt install -y nodejs
```

**3. "Cannot find module" errors**
```bash
# Rebuild native modules
npm rebuild

# Or delete node_modules and reinstall
rm -rf node_modules package-lock.json
npm install
```

---

## Python Setup

### Latest Stable Version
**Python 3.12.x**

**Why 3.12?**
- Latest stable release
- Performance improvements
- New language features
- Better error messages

---

### Installation

#### Check Pre-installed Version

```bash
# Check current Python version
python3 --version

# Ubuntu 24.04 typically comes with Python 3.12
# If you need a specific version, see below
```

#### Installing Specific Python Version

```bash
# Add deadsnakes PPA (for multiple Python versions)
sudo add-apt-repository ppa:deadsnakes/ppa
sudo apt update

# Install Python 3.12
sudo apt install -y python3.12 python3.12-venv python3.12-dev

# Install pip for Python 3.12
sudo apt install -y python3-pip

# Verify
python3.12 --version
```

**What gets installed:**
- `python3.12` - Python interpreter
- `python3.12-venv` - Virtual environment support
- `python3.12-dev` - Development headers (for compiling packages)
- `python3-pip` - Package manager

---

### Virtual Environments

**Always use virtual environments** to avoid package conflicts:

```bash
# Create virtual environment
python3 -m venv myproject-env

# Activate
source myproject-env/bin/activate

# You'll see (myproject-env) in your prompt

# Install packages (isolated from system Python)
pip install requests flask django

# Deactivate when done
deactivate
```

**Best Practices:**
- One virtual environment per project
- Never install packages with `sudo pip`
- Commit `requirements.txt`, not the venv folder

---

### Managing Dependencies

**Creating requirements.txt:**
```bash
# After installing packages in your venv
pip freeze > requirements.txt
```

**Installing from requirements.txt:**
```bash
pip install -r requirements.txt
```

**Example requirements.txt:**
```
requests==2.31.0
flask==3.0.0
python-dotenv==1.0.0
gunicorn==21.2.0
```

**Using ~= for compatible updates:**
```
requests~=2.31    # 2.31.0 or higher, but < 3.0.0
flask~=3.0        # 3.0.0 or higher, but < 4.0.0
```

---

### Running Python Applications

**Development:**
```bash
python3 app.py
# or
python3 -m flask run
```

**Production (with Gunicorn):**
```bash
# Install gunicorn
pip install gunicorn

# Run with multiple workers
gunicorn -w 4 -b 0.0.0.0:8000 app:app
```

**Systemd Service (auto-start):**
```bash
# Create service file
sudo nano /etc/systemd/system/myapp.service
```

```ini
[Unit]
Description=My Python App
After=network.target

[Service]
User=deployer
Group=deployer
WorkingDirectory=/home/deployer/apps/myapp
Environment="PATH=/home/deployer/apps/myapp/myproject-env/bin"
Environment="PYTHONPATH=/home/deployer/apps/myapp"
Environment="PORT=8000"
ExecStart=/home/deployer/apps/myapp/myproject-env/bin/gunicorn -w 4 -b 0.0.0.0:8000 app:app

[Install]
WantedBy=multi-user.target
```

```bash
# Enable and start
sudo systemctl enable myapp
sudo systemctl start myapp
sudo systemctl status myapp
```

---

### Common Python Issues

**1. pip not found**
```bash
sudo apt install -y python3-pip
# Use as: python3 -m pip install package
```

**2. "externally-managed-environment" error**
```bash
# Option 1: Use virtual environment (recommended)
python3 -m venv myenv
source myenv/bin/activate
pip install package

# Option 2: Force install (not recommended)
pip install --break-system-packages package
```

**3. Module not found in production**
```bash
# Make sure you're in the virtual environment
source myproject-env/bin/activate

# Verify package is installed
pip list | grep package-name

# Reinstall if needed
pip install package-name
```

**4. Permission errors**
```bash
# NEVER use sudo with pip in virtual environments
# Virtual environments don't need sudo

# If you used sudo by mistake:
sudo chown -R $USER:$USER /path/to/project
rm -rf venv
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

---

## Quick Reference

### Check Versions
```bash
# Node.js
node --version
npm --version

# Python
python3 --version
pip --version
which python3
```

### Update Packages
```bash
# Update npm globally
sudo npm install -g npm@latest

# Update pip
python3 -m pip install --upgrade pip

# Update all packages in requirements.txt
pip install -r requirements.txt --upgrade
```

### Environment Variables
```bash
# Node.js
export NODE_ENV=production
export PORT=3000

# Python
export FLASK_ENV=production
export PYTHONPATH=/path/to/project
```

---

## Recommended Versions Summary

| Tool | Version | Notes |
|------|---------|-------|
| **Node.js** | 24.x LTS | Production stable |
| **npm** | 11.x | Comes with Node.js 24 |
| **Python** | 3.12.x | Latest stable |
| **pip** | 24.x | Latest |
| **PM2** | Latest | Process manager |
| **Gunicorn** | 21.x | Python WSGI server |

---

## Next Steps

1. **Set up your first Node.js app** with PM2
2. **Create a Python virtual environment** for your scripts
3. **Configure systemd services** for production apps
4. **Set up log rotation** for application logs
5. **Configure nginx reverse proxy** for your apps

---

## Troubleshooting Checklist

**Before asking for help:**

- [ ] Check versions: `node --version`, `python3 --version`
- [ ] Verify you're in the correct directory
- [ ] For Python: Virtual environment activated?
- [ ] Check logs: `pm2 logs`, `journalctl -u myapp`
- [ ] Check ports: `sudo netstat -tlnp | grep :80`
- [ ] Check permissions: `ls -la` in project directory
- [ ] Check firewall: `sudo ufw status`
- [ ] Check nginx: `sudo nginx -t`, `sudo systemctl status nginx`
