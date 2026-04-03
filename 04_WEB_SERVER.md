# Web Server Setup Guide

Complete guide for setting up nginx web server, SSL certificates, and hosting websites on your VPS.

---

## Table of Contents

1. [Nginx Installation](#nginx-installation)
2. [Basic Nginx Configuration](#basic-nginx-configuration)
3. [SSL Certificates with Certbot](#ssl-certificates-with-certbot)
4. [Hosting Static Websites](#hosting-static-websites)
5. [Reverse Proxy for Node.js Apps](#reverse-proxy-for-nodejs-apps)
6. [Multiple Sites Configuration](#multiple-sites-configuration)
7. [Log Management](#log-management)

---

## Nginx Installation

### Install Nginx

```bash
sudo apt update
sudo apt install -y nginx
```

### Verify Installation

```bash
# Check nginx version
nginx -v

# Test configuration
sudo nginx -t

# Check if nginx is running
sudo systemctl status nginx
```

### Start and Enable Nginx

```bash
# Start nginx
sudo systemctl start nginx

# Enable auto-start on boot
sudo systemctl enable nginx
```

**Check it's working:** Visit your server IP in a browser. You should see the nginx welcome page.

---

## Basic Nginx Configuration

### Understanding the File Structure

```
/etc/nginx/
├── nginx.conf              # Main configuration
├── sites-available/        # Site configs (not active yet)
│   ├── default
│   └── your-site.com
└── sites-enabled/          # Active site configs (symlinks)
    └── your-site.com -> ../sites-available/your-site.com
```

**Key principle:** Create configs in `sites-available/`, then create symlinks in `sites-enabled/` to activate them.

### Main Nginx Configuration

Edit the main config:
```bash
sudo nano /etc/nginx/nginx.conf
```

**Production-optimized configuration:**

```nginx
user www-data;
worker_processes auto;
pid /run/nginx.pid;
error_log /var/log/nginx/error.log;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 768;
    use epoll;              # Best for Linux performance
    multi_accept on;        # Accept multiple connections per worker
}

http {
    ##
    # Basic Settings
    ##
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;         # Better for frequent small requests (APIs, Next.js)
    keepalive_timeout 65;   # Close idle connections faster (free up resources)
    types_hash_max_size 2048;
    server_tokens off;      # Hide nginx version (security)

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    ##
    # SSL Settings
    ##
    # Only TLS 1.2+ (1.0 and 1.1 are deprecated, have vulnerabilities)
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;  # Let client choose (better browser compatibility)
    
    # Strong cipher suite for modern browsers
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;

    ##
    # Logging Settings
    ##
    access_log /var/log/nginx/access.log combined buffer=512k flush=1m;
    error_log /var/log/nginx/error.log;
    # Buffer reduces disk I/O by batching writes (better performance under load)

    ##
    # Gzip Settings
    ##
    gzip on;
    gzip_vary on;           # Tell proxies to cache gzipped separately
    gzip_proxied any;       # Compress proxied requests too
    gzip_comp_level 6;      # Balance between size and CPU usage
    gzip_types text/plain text/css text/xml application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
    # Compress text files by 60-80%

    ##
    # Security Headers
    ##
    # Add to all responses (can also be in site configs)
    add_header X-Frame-Options "SAMEORIGIN" always;           # Prevent clickjacking
    add_header X-Content-Type-Options "nosniff" always;       # Prevent MIME sniffing
    add_header X-XSS-Protection "1; mode=block" always;       # Basic XSS protection

    ##
    # Virtual Host Configs
    ##
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
```

**Why These Changes Matter:**

| Setting | Why It's Important |
|---------|-------------------|
| `use epoll` | Linux's most efficient event notification mechanism |
| `multi_accept on` | Worker accepts all new connections at once instead of one-by-one (better under load) |
| `tcp_nodelay on` | Better for web apps with frequent small requests (Next.js, APIs) |
| `keepalive_timeout 65` | Frees up connections faster, saves memory |
| `server_tokens off` | Hides nginx version from error pages (security through obscurity) |
| `ssl_protocols TLSv1.2 TLSv1.3` | Removes deprecated/insecure TLS 1.0 and 1.1 |
| `ssl_prefer_server_ciphers off` | Lets client choose best cipher (better compatibility) |
| `access_log ... buffer` | Reduces disk I/O significantly under high load |
| `gzip_vary on` | Ensures proxies cache gzipped and non-gzipped separately |
| `gzip_comp_level 6` | Level 1 = fast but large, 9 = slow but small. 6 is the sweet spot |
| `Security headers` | Protects against common web attacks |

**Test and reload:**
```bash
sudo nginx -t
sudo systemctl reload nginx
```

**Default vs Optimized:**

The default config works, but these optimizations provide:
- **Better security** (TLS 1.2+, hidden version, security headers)
- **Better performance** (epoll, multi_accept, compression, log buffering)
- **Lower resource usage** (keepalive, gzip, efficient event handling)
- **Production-ready defaults** for hosting multiple Node.js/React apps

---

## SSL Certificates with Certbot

### Install Certbot

```bash
sudo apt install -y certbot python3-certbot-nginx
```

### Get SSL Certificate

**Method 1: Automatic nginx configuration (easiest)**

```bash
# Replace with your actual domain
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com
```

Certbot will:
- Verify domain ownership
- Obtain certificate from Let's Encrypt
- Automatically configure nginx
- Set up auto-renewal

**Method 2: Manual certificate only**

```bash
# Get certificate without auto-configuring nginx
sudo certbot certonly --nginx -d yourdomain.com

# Then manually configure nginx to use the certificate
```

### Test Auto-Renewal

```bash
# Test renewal process (dry run)
sudo certbot renew --dry-run
```

Certbot automatically sets up a cron job to renew certificates. They expire every 90 days.

---

## Step-by-Step: Adding Your First Site

Complete walkthrough for setting up a new website from scratch, using a simple HTML example. We'll use **brewapps.poinglabs.com** as our example domain.

**Summary Checklist:**

- [ ] Create directory structure for production and dev sites
- [ ] Set correct ownership and permissions (deployer user, 755)
- [ ] Create simple HTML files for each environment
- [ ] Create nginx configuration files for each site
- [ ] Enable sites by creating symlinks in sites-enabled
- [ ] Set up DNS A records for domains
- [ ] Get SSL certificates with Certbot
- [ ] Test both sites in browser

### Step 1: Create the Directory Structure

**Important:** Use a project-based folder structure with `prod` and `stage` subfolders. This keeps all environments organized under one project folder.

```bash
# Create project folder structure
# brewapps = project name (not domain-specific)
sudo mkdir -p /var/www/brewapps/prod/html
sudo mkdir -p /var/www/brewapps/stage/html

# Set ownership to deployer user (or your user)
sudo chown -R deployer:deployer /var/www/brewapps

# Set correct permissions
sudo chmod -R 755 /var/www/brewapps
```

**New Folder Structure:**
```
/var/www/
└── brewapps/              # Project folder (generic name)
    ├── prod/              # Production environment
    │   └── html/          # Production website files
    └── stage/             # Staging/development environment
        └── html/          # Staging website files
```

**Benefits of this structure:**
- All environments in one place
- Easy to find and manage
- Can add more environments later (test, demo, etc.)
- Domain changes only require nginx config updates

**Why Ownership and Permissions Matter:**

**1. Ownership (`chown deployer:deployer`)**

This command says: "Make the `deployer` user and `deployer` group the owners of these folders."

```
# Format: sudo chown -R user:group /path/to/folder
# -R means "recursive" (apply to all subfolders and files)

Before:  /var/www/brewapps is owned by root
After:   /var/www/brewapps is owned by deployer
```

**Why?**
- **Nginx runs as `www-data` user** - needs to read the files
- **You edit files as `deployer` user** - needs to write/delete files
- **Root owns system folders** - but we don't want to edit files as root (security risk)

**What happens if ownership is wrong:**
- You can't edit files: "Permission denied" when trying to save changes
- GitHub Actions can't deploy: "Permission denied" when copying files
- You have to use `sudo` for everything (bad practice)

**2. Permissions (`chmod 755`)**

This sets who can read, write, or execute files in these folders.

```
755 means:
┌─────────────────────────────────────────┐
│ 7 (Owner)   │ Read + Write + Execute   │ deployer can do anything
│ 5 (Group)   │ Read + Execute           │ www-data can read (serve) files
│ 5 (Others)  │ Read + Execute           │ Anyone can view website
└─────────────────────────────────────────┘

Numbers explained:
7 = 4+2+1 = Read(4) + Write(2) + Execute(1)
5 = 4+0+1 = Read(4) + No Write(0) + Execute(1)
```

**Why 755?**
- **Owner (deployer)**: Full control - can add, edit, delete files
- **Group (www-data)**: Can read files to serve them to visitors
- **Others**: Can view the website (that's what we want!)

**Common permission numbers:**
- `755` - Folders and executable files (what we use here)
- `644` - Regular files (readable by all, writable only by owner)
- `600` - Private files (SSH keys, passwords) - only owner can read
- `777` - Everyone can do everything (**DANGEROUS** - never use on web files!)

**What happens if permissions are wrong:**
- `700` (owner only): Website visitors get "403 Forbidden" error
- `777` (everyone): Security risk - anyone can modify your files!
- `644` on folders: Nginx can't access subdirectories

**Real Example:**

```bash
# Check current permissions
ls -la /var/www/
# Output: drwxr-xr-x 3 deployer deployer 4096 Jan 15 10:30 brewapps
#         ^^^^
#         7 5 5 = rwx r-x r-x

# The 'd' means it's a directory
# rwx = owner (7) has read, write, execute
# r-x = group (5) has read, execute (no write)
# r-x = others (5) has read, execute (no write)
```

**Quick Fix if Something Breaks:**

```bash
# If you get "Permission denied" errors:
# 1. Fix ownership
sudo chown -R deployer:deployer /var/www/brewapps

# 2. Fix permissions
sudo chmod -R 755 /var/www/brewapps

# 3. For files inside, use 644 (more secure)
find /var/www/brewapps/html -type f -exec chmod 644 {} \;
```

**Why generic names?**

The folder structure uses a project-based approach with environment subfolders. Here's why:

1. **Organization**: One project folder contains all environments:
   - `prod/` - Production files
   - `stage/` - Staging/development files
   - Easy to add `test/`, `demo/`, etc. later
2. **Convention**: Each environment has an `html/` subfolder for publicly accessible files
3. **Security**: Parent folders can hold private files (logs, configs) that won't be served
4. **Nginx `root` directive**: Points to the `html` folder for each environment

**Example structure:**
```
/var/www/brewapps/           # Project folder
├── prod/                    # Production environment
│   ├── html/               # Public files (root for nginx)
│   │   ├── index.html
│   │   ├── css/
│   │   └── js/
│   ├── logs/               # Production logs
│   └── config/             # Production configs
└── stage/                   # Staging environment
    ├── html/               # Public files (root for nginx)
    │   ├── index.html
    │   ├── css/
    │   └── js/
    └── logs/               # Staging logs
```

**Why this structure?**
- All environments organized in one place
- Easy domain changes (just update nginx `server_name`)
- Can add environments without cluttering `/var/www/`
- Consistent naming across all projects

### Step 2: Create a Simple HTML File

```bash
# Create index.html for production
cat > /var/www/brewapps/prod/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>BrewApps - Production</title>
    <style>
        body { 
            font-family: Arial, sans-serif; 
            text-align: center; 
            padding: 50px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        h1 { font-size: 3em; margin-bottom: 20px; }
        .version { font-size: 1.5em; opacity: 0.9; }
    </style>
</head>
<body>
    <h1>Welcome to BrewApps!</h1>
    <p class="version">Production Environment</p>
    <p>Server time: <span id="time"></span></p>
    <script>
        document.getElementById('time').textContent = new Date().toLocaleString();
    </script>
</body>
</html>
EOF

# Create index.html for staging
cat > /var/www/brewapps/stage/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>BrewApps - Staging</title>
    <style>
        body { 
            font-family: Arial, sans-serif; 
            text-align: center; 
            padding: 50px;
            background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
            color: white;
        }
        h1 { font-size: 3em; margin-bottom: 20px; }
        .version { font-size: 1.5em; opacity: 0.9; }
        .stage-badge {
            background: #ff6b6b;
            color: white;
            padding: 10px 20px;
            border-radius: 20px;
            display: inline-block;
            margin-top: 20px;
        }
    </style>
</head>
<body>
    <h1>Welcome to BrewApps!</h1>
    <p class="version">Staging Environment</p>
    <div class="stage-badge">STAGE MODE</div>
    <p>Server time: <span id="time"></span></p>
    <script>
        document.getElementById('time').textContent = new Date().toLocaleString();
    </script>
</body>
</html>
EOF
```

### Step 3: Create Nginx Configuration Files

Nginx uses configuration files to tell it:
1. Which domains to listen for
2. Where to find the website files
3. How to handle different types of requests

**Production site config:**

```bash
sudo nano /etc/nginx/sites-available/brewapps-prod
```

```nginx
server {
    # Which ports to listen on
    listen 80;           # IPv4 HTTP
    listen [::]:80;      # IPv6 HTTP
    
    # Domain mapping - which domain(s) this config handles
    # Change this if you change your domain
    server_name brewapps.poinglabs.com;
    
    # Where to find website files (the "root" of your site)
    # Points to the prod/html folder we created
    root /var/www/brewapps/prod/html;
    
    # Default file to serve when someone visits the directory
    # Nginx looks for these in order: index.html, then index.htm
    index index.html index.htm;
    
    # How to handle requests
    location / {
        # Try to serve the file, then the directory, or return 404
        # $uri = the requested file (e.g., /about.html)
        # $uri/ = the requested directory (e.g., /about/)
        # =404 = return "not found" error if neither exists
        try_files $uri $uri/ =404;
    }
    
    # Security headers - added to every response
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
}
```

**Staging site config:**

```bash
sudo nano /etc/nginx/sites-available/brewapps-stage
```

```nginx
server {
    listen 80;
    listen [::]:80;
    
    # Different domain for staging environment
    server_name stage.brewapps.poinglabs.com;
    
    # Points to the stage/html folder
    root /var/www/brewapps/stage/html;
    index index.html index.htm;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
}
```

**Breaking down the nginx config:**

| Directive | What It Does | Example |
|-----------|--------------|---------|
| `listen 80` | Tells nginx to accept HTTP connections on port 80 | When someone types http://yoursite.com |
| `server_name` | Which domain(s) this config applies to | `brewapps.poinglabs.com` |
| `root` | Where website files are located | `/var/www/brewapps/prod/html` |
| `index` | Default file to show when visiting a folder | `index.html` |
| `location /` | Rules for all requests | Handles every URL |
| `try_files` | What to try when someone requests a URL | File → Directory → 404 error |
| `add_header` | Security headers added to all responses | Prevents clickjacking, etc. |

**How it works when someone visits your site:**

```
User types: https://brewapps.poinglabs.com/about

1. Browser → DNS lookup → finds your server IP
2. Browser → HTTP request to your server on port 80/443
3. Nginx receives request
4. Nginx checks: "Does server_name match brewapps.poinglabs.com?" ✓
5. Nginx looks in root folder: /var/www/brewapps/prod/html/
6. Nginx looks for: /var/www/brewapps/prod/html/about
   - If exists: serve it
   - If not: try /var/www/brewapps/prod/html/about/
   - If neither: return 404 error
7. Nginx sends file back to browser with security headers
8. Browser displays the page
```

**Key concept:** `server_name` maps domains to folders. The folder name is independent of the domain!

### Step 4: Enable the Sites

```bash
# Create symlinks to enable sites
sudo ln -s /etc/nginx/sites-available/brewapps-prod /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/brewapps-stage /etc/nginx/sites-enabled/

# Test nginx configuration
sudo nginx -t

# Reload nginx to apply changes
sudo systemctl reload nginx
```

### Disable a Site

To disable a site (temporarily take it offline without deleting the configuration):

```bash
# Remove the symlink from sites-enabled
sudo rm /etc/nginx/sites-enabled/brewapps-stage

# Test configuration
sudo nginx -t

# Reload nginx to apply changes
sudo systemctl reload nginx
```

**What happens:**
- The site becomes unavailable (visitors see default nginx page or 404)
- The config file in `sites-available/` remains intact
- You can re-enable later by recreating the symlink

**When to disable:**
- Maintenance mode
- Temporary takedown
- Troubleshooting issues
- Before deleting a site permanently

### Step 5: Set Up DNS

In your domain registrar or DNS provider (wherever you manage poinglabs.com DNS):

1. **Add A records:**
   ```
   Type: A
   Name: brewapps
   Value: YOUR_SERVER_IP
   TTL: 3600
   
   Type: A
   Name: stage.brewapps
   Value: YOUR_SERVER_IP
   TTL: 3600
   ```

2. **Wait for DNS propagation** (usually 5-60 minutes)

3. **Test:**
   ```bash
   # Check if DNS is working
   nslookup brewapps.poinglabs.com
   nslookup stage.brewapps.poinglabs.com
   
   # Should return your server IP
   ```

### Step 6: Get SSL Certificates

```bash
# Get certificate for production
sudo certbot --nginx -d brewapps.poinglabs.com

# Get certificate for staging
sudo certbot --nginx -d stage.brewapps.poinglabs.com

# Test auto-renewal
sudo certbot renew --dry-run
```

**Certbot will:**
- Verify you own the domain
- Get SSL certificates from Let's Encrypt
- Automatically update your nginx configs to use HTTPS
- Redirect HTTP to HTTPS

### Step 7: Test Your Sites

Open in browser:
- https://brewapps.poinglabs.com (should show "Production Environment")
- https://stage.brewapps.poinglabs.com (should show "Staging Environment" with red badge)

You now have two working sites with SSL!

---

## GitHub Actions Auto-Deployment

Now let's set up automatic deployment when you push to specific branches.

### Step 1: Set Up SSH Keys for GitHub Actions

**Method A: Manual Setup (For Deployer User)**

Since Hetzner Console only adds SSH keys for the root user, you'll need to manually add the key for the deployer user:

**1. Generate SSH Key Pair (on your local machine):**

```bash
# Generate a new SSH key specifically for GitHub Actions
# Do NOT add a passphrase (press Enter when asked)
ssh-keygen -t ed25519 -C "github-actions@brewapps" -f ~/.ssh/github_actions_deploy

# This creates two files:
# ~/.ssh/github_actions_deploy     (private key - keep secret!)
# ~/.ssh/github_actions_deploy.pub (public key - safe to share)
```

**2. Add Public Key to Deployer User on Server:**

SSH into your server as the deployer user, then:

```bash
# Create .ssh directory if it doesn't exist
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Add the public key to authorized_keys
echo "ssh-ed25519 AAAAC3NzaC... github-actions@brewapps" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

Replace the `ssh-ed25519 AAAAC3NzaC...` part with your actual public key from `~/.ssh/github_actions_deploy.pub`.

**Alternative: Copy from your local machine:**

```bash
# On your local machine, copy the public key
cat ~/.ssh/github_actions_deploy.pub | pbcopy  # macOS
# or
cat ~/.ssh/github_actions_deploy.pub  # Linux - copy manually

# Then paste it into the server's ~/.ssh/authorized_keys file
```

**Method B: Using Hetzner Console (Root User Only)**

If you prefer using the Hetzner Console (note: this only works for the root user):

1. **Copy the public key:**
   ```bash
   cat ~/.ssh/github_actions_deploy.pub
   ```

2. **In Hetzner Cloud Console:**
   - Go to your Project
   - Click **"Security"** → **"SSH Keys"**
   - Click **"Add SSH Key"**
   - **Name:** `github-actions-deploy`
   - **Public Key:** Paste the key
   - Click **"Add SSH Key"**

3. **Attach Key to Your Server** (keys are applied immediately)

**Add Private Key to GitHub:**

1. **Copy the private key:**
   ```bash
   cat ~/.ssh/github_actions_deploy
   # Copy the entire output
   ```

2. **In GitHub Repository:**
   - Go to **Settings** → **Secrets and variables** → **Actions**
   - Click **"New repository secret"**
   - **Name:** `SSH_PRIVATE_KEY`
   - **Value:** Paste the private key
   - Click **"Add secret"**

**Add Other Secrets:**

```
Name: SERVER_IP
Value: YOUR_SERVER_IP_ADDRESS

Name: SERVER_USER
Value: deployer
```

**Note:** Use Method A (manual setup) if you're using the deployer user for deployments, as Hetzner Console only adds keys for root.

### Step 2: Create GitHub Actions Workflow

This guide uses the **GitHub Actions-only method** - all deployment logic is in the workflow file. You can add build steps (npm install, npm run build) directly here.

**Benefits:**
- ✅ Everything in one place (GitHub)
- ✅ Easy to add build steps
- ✅ Version controlled with your code
- ✅ Can rollback to specific commits

**Create the workflow file:**

In your repository, create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to Server

on:
  push:
    branches:
      - main
      - dev

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
    # Step 1: Checkout the code
    - name: Checkout code
      uses: actions/checkout@v4
      
    # Step 2: Setup Node.js (if you need to build)
    # Uncomment and adjust version if building Node.js/React apps
    # - name: Setup Node.js
    #   uses: actions/setup-node@v4
    #   with:
    #     node-version: '20'
    #     cache: 'npm'
    #
    # - name: Install dependencies
    #   run: npm ci
    #
    # - name: Build project
    #   run: npm run build
    #
    # After build, the static files will be in your build folder
    # (e.g., dist/, build/, .next/out/, etc.)
    
    # Step 3: Setup SSH
    - name: Setup SSH
      uses: webfactory/ssh-agent@v0.9.1
      with:
        ssh-private-key: ${{ secrets.SSH_PRIVATE_KEY }}
        
    # Step 4: Add server to known hosts
    - name: Add server to known hosts
      run: |
        mkdir -p ~/.ssh
        ssh-keyscan -H ${{ secrets.SERVER_IP }} >> ~/.ssh/known_hosts
        
    # Step 5: Deploy to Production (main branch)
    - name: Deploy to production
      if: github.ref == 'refs/heads/main'
      run: |
        echo "Deploying to production..."
        
        # For static HTML sites:
        # Copy all files to server (adjust path if using build folder)
        rsync -avz --delete \
          -e "ssh -i ~/.ssh/id_rsa" \
          ./ \
          ${{ secrets.SERVER_USER }}@${{ secrets.SERVER_IP }}:/var/www/brewapps/prod/html/
        
        # Set correct permissions
        ssh ${{ secrets.SERVER_USER }}@${{ secrets.SERVER_IP }} \
          'sudo chown -R deployer:deployer /var/www/brewapps/prod/html && sudo chmod -R 755 /var/www/brewapps/prod/html'
        
        echo "Production deployment complete!"
        
    # Step 6: Deploy to Staging (dev branch)  
    - name: Deploy to staging
      if: github.ref == 'refs/heads/dev'
      run: |
        echo "Deploying to staging..."
        
        # For static HTML sites:
        rsync -avz --delete \
          -e "ssh -i ~/.ssh/id_rsa" \
          ./ \
          ${{ secrets.SERVER_USER }}@${{ secrets.SERVER_IP }}:/var/www/brewapps/stage/html/
        
        # Set correct permissions
        ssh ${{ secrets.SERVER_USER }}@${{ secrets.SERVER_IP }} \
          'sudo chown -R deployer:deployer /var/www/brewapps/stage/html && sudo chmod -R 755 /var/www/brewapps/stage/html'
        
        echo "Staging deployment complete!"
```

### Build Steps Example (React/Next.js)

If you have a React or Next.js app that needs building:

```yaml
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
      
    # BUILD STEPS - uncomment for Node.js apps
    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '20'
        cache: 'npm'
    
    - name: Install dependencies
      run: npm ci
    
    - name: Build project
      run: npm run build
    
    # For Next.js static export:
    # - name: Build static site
    #   run: npm run build  # Make sure next.config.js has output: 'export'
    
    # Then deploy the build folder:
    - name: Deploy to production
      if: github.ref == 'refs/heads/main'
      run: |
        # For Next.js: deploy the 'out' folder
        rsync -avz --delete \
          -e "ssh -i ~/.ssh/id_rsa" \
          ./out/ \
          ${{ secrets.SERVER_USER }}@${{ secrets.SERVER_IP }}:/var/www/brewapps/prod/html/
        
        # For React (create-react-app): deploy the 'build' folder
        # rsync -avz --delete \
        #   -e "ssh -i ~/.ssh/id_rsa" \
        #   ./build/ \
        #   ${{ secrets.SERVER_USER }}@${{ secrets.SERVER_IP }}:/var/www/brewapps/prod/html/
```

### Rollback to Specific Commit

**IMPORTANT:** If you need to rollback to a previous version, you have two options:

**Option 1: Revert the commit and push**
```bash
# Find the commit you want to go back to
git log --oneline

# Revert that specific commit (creates a new "undo" commit)
git revert abc123

# Or if you want to completely reset to a previous commit
# (DANGER: This removes commits permanently!)
git reset --hard abc123
git push --force origin main  # Only if necessary
```

**Option 2: Create a rollback branch (Safer)**
```bash
# Create a hotfix branch from the last good commit
git checkout -b hotfix-rollback abc123

# Push the branch
git push origin hotfix-rollback

# Open a PR to merge hotfix-rollback into main
# This preserves history and is reversible
```

**Option 3: Manual rollback via GitHub UI**
1. Go to your repo on GitHub
2. Click on the commit you want to rollback to
3. Click "Browse files" → "Code" dropdown → "Download ZIP"
4. Manually upload files to server (emergency only)

**Pro Tip:** For critical production sites, consider using GitHub Releases instead of direct branch deployment. This gives you explicit version control and easy rollbacks.

### Step 3: Test Auto-Deployment

1. **Make a change** in your repository (edit index.html)

2. **Commit and push to dev branch:**
   ```bash
   git add .
   git commit -m "Update dev site"
   git push origin dev
   ```

3. **Check GitHub Actions:**
   - Go to your repo → Actions tab
   - You should see the workflow running
   - Wait for it to complete (green checkmark)

4. **Verify deployment:**
   - Visit https://stage.brewapps.poinglabs.com
   - Your changes should be live!

5. **Test production:**
   ```bash
   git checkout main
   git merge dev
   git push origin main
   ```
   - Check https://brewapps.poinglabs.com

### Verify Files on Server

After deployment, SSH into your server to verify files were synced correctly:

```bash
# Check production files
ls -la /var/www/brewapps/prod/html/

# Check staging files
ls -la /var/www/brewapps/stage/html/

# View the index.html to confirm it's the latest version
cat /var/www/brewapps/prod/html/index.html

# Check file timestamps (should show recent time)
stat /var/www/brewapps/prod/html/index.html
```

**Common checks:**
- Files should have recent timestamps
- Ownership should be `deployer:deployer`
- Permissions should be `755` for directories, `644` for files
- Content should match what you pushed to GitHub

### Complete Workflow Summary

```
Developer workflow:
├── Work on feature locally
├── Push to dev branch
├── GitHub Actions auto-deploys to stage.brewapps.poinglabs.com
├── Test on staging site
├── Merge dev → main
├── GitHub Actions auto-deploys to brewapps.poinglabs.com
└── Production is updated!
```

### Changing Domains (Easy with Generic Folders!)

If you change domains later (e.g., from `brewapps.poinglabs.com` to `brewapps.com`):

```bash
# 1. Update nginx configs - only change server_name
sudo nano /etc/nginx/sites-available/brewapps-prod
# Change: server_name brewapps.com;

sudo nano /etc/nginx/sites-available/brewapps-stage
# Change: server_name stage.brewapps.com;

# 2. Get new SSL certificates
sudo certbot --nginx -d brewapps.com
sudo certbot --nginx -d stage.brewapps.com

# 3. Reload nginx
sudo nginx -t && sudo systemctl reload nginx

# Done! Your folders (/var/www/brewapps/prod and /var/www/brewapps/stage) stay the same
```

**Why this is better:**
- No file moving or renaming
- No broken paths in deployment scripts
- No updating GitHub Actions
- Just 3 commands and you're live on the new domain!

---

## Hosting Static Websites (Project-Based Folder Approach)

### Create Site Directory

**Use project names with environment subfolders:**

```bash
# Create project folder with prod and stage environments
sudo mkdir -p /var/www/my-project/prod/html
sudo mkdir -p /var/www/my-project/stage/html

# Set correct ownership
sudo chown -R deployer:deployer /var/www/my-project

# Set correct permissions
sudo chmod -R 755 /var/www/my-project
```

### Create Nginx Config

```bash
# Production config
sudo nano /etc/nginx/sites-available/my-project-prod
```

Production static site config:
```nginx
server {
    listen 80;
    listen [::]:80;
    
    # Domain can change easily, folder stays the same
    server_name yourdomain.com www.yourdomain.com;
    
    # Point to prod environment
    root /var/www/my-project/prod/html;
    index index.html index.htm;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
}
```

Staging config:
```bash
sudo nano /etc/nginx/sites-available/my-project-stage
```

```nginx
server {
    listen 80;
    listen [::]:80;
    
    server_name stage.yourdomain.com;
    
    # Point to stage environment
    root /var/www/my-project/stage/html;
    index index.html index.htm;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
}
```

### Enable the Site

```bash
# Create symlinks to enable both environments
sudo ln -s /etc/nginx/sites-available/my-project-prod /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/my-project-stage /etc/nginx/sites-enabled/

# Test configuration
sudo nginx -t

# Reload nginx
sudo systemctl reload nginx
```

### Disable the Site

```bash
# Remove symlinks to disable sites
sudo rm /etc/nginx/sites-enabled/my-project-prod
sudo rm /etc/nginx/sites-enabled/my-project-stage

# Test configuration
sudo nginx -t

# Reload nginx
sudo systemctl reload nginx
```

**Note:** The config files in `sites-available/` remain - you can re-enable anytime by recreating the symlinks.

### Deploy Your Static Files

```bash
# Deploy to production
cp -r /path/to/your/dist/* /var/www/my-project/prod/html/

# Deploy to staging
cp -r /path/to/your/dist/* /var/www/my-project/stage/html/

# Or using rsync for remote deployment:
# rsync -avz --delete ./dist/ user@server:/var/www/my-project/prod/html/
```

### Why Generic Names?

| Approach | Pros | Cons |
|----------|------|------|
| **Domain-based** (`yourdomain.com`) | Clear what site it is | Hard to change domains, need to rename everything |
| **Project-based** (`my-project`) | Easy domain changes, consistent deployment scripts | Slightly less obvious |

**Recommendation:** Always use project-based names. Your nginx config maps domains to folders, so changing domains only requires updating `server_name` in one place.

---

## Reverse Proxy for Node.js Apps

When your app runs on a port (like Next.js on 3000), nginx acts as a reverse proxy.

### Simple Reverse Proxy Config

```bash
sudo nano /etc/nginx/sites-available/yourdomain.com
```

```nginx
server {
    listen 80;
    server_name yourdomain.com;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

### With SSL (Production)

```nginx
server {
    listen 80;
    server_name yourdomain.com www.yourdomain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    
    server_name yourdomain.com www.yourdomain.com;
    
    # SSL certificates (from Certbot)
    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;
    ssl_trusted_certificate /etc/letsencrypt/live/yourdomain.com/chain.pem;
    
    # SSL configuration
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers off;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    # Gzip
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml application/json application/javascript;
    
    # Proxy to Node.js app
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
    
    # Static files (optional - serve directly for better performance)
    location /_next/static/ {
        alias /home/deployer/apps/your-app/.next/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

---

## Multiple Sites Configuration

### Folder Structure

Use **project names** with environment subfolders for better organization:

```
/var/www/
├── brewapps/                 # Project folder
│   ├── prod/                # Production environment
│   │   └── html/            # Production files
│   └── stage/               # Staging environment
│       └── html/            # Staging files
├── project-one/             # Another project
│   ├── prod/
│   │   └── html/
│   └── stage/
│       └── html/
└── blog/
    ├── prod/
    │   └── html/
    └── stage/
        └── html/
```

### Example: Multiple Sites with Environment Subfolders

**brewapps-prod** (Next.js on port 3000):
```nginx
server {
    listen 443 ssl http2;
    server_name brewapps.poinglabs.com;
    
    ssl_certificate /etc/letsencrypt/live/brewapps.poinglabs.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/brewapps.poinglabs.com/privkey.pem;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

**brewapps-stage** (Next.js on port 3001):
```nginx
server {
    listen 443 ssl http2;
    server_name stage.brewapps.poinglabs.com;
    
    ssl_certificate /etc/letsencrypt/live/stage.brewapps.poinglabs.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/stage.brewapps.poinglabs.com/privkey.pem;
    
    location / {
        proxy_pass http://localhost:3001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

**blog-prod** (Static files):
```nginx
server {
    listen 443 ssl http2;
    server_name blog.mysite.com;
    
    ssl_certificate /etc/letsencrypt/live/blog.mysite.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/blog.mysite.com/privkey.pem;
    
    # Points to prod environment
    root /var/www/blog/prod/html;
    index index.html;
    
    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

### Enable All Sites

```bash
# Create symlinks for all sites (use project-environment naming)
sudo ln -s /etc/nginx/sites-available/brewapps-prod /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/brewapps-stage /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/blog-prod /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/blog-stage /etc/nginx/sites-enabled/

# Test and reload
sudo nginx -t
sudo systemctl reload nginx
```

### Disable All Sites (or Specific Ones)

```bash
# Disable specific sites
sudo rm /etc/nginx/sites-enabled/brewapps-stage
sudo rm /etc/nginx/sites-enabled/blog-stage

# Disable all sites at once (careful!)
# sudo rm /etc/nginx/sites-enabled/*

# Test and reload
sudo nginx -t
sudo systemctl reload nginx
```

**Note:** Disabling sites only removes the symlinks in `sites-enabled/`. The actual configuration files remain safe in `sites-available/`.

---

## Log Management

### Log Locations

```
/var/log/nginx/
├── access.log        # All HTTP requests
├── error.log         # Errors and warnings
└── yourdomain.access.log  # Per-site logs (if configured)
```

### View Logs in Real-time

```bash
# Watch access log
sudo tail -f /var/log/nginx/access.log

# Watch error log
sudo tail -f /var/log/nginx/error.log

# Filter for specific site
grep "site1.com" /var/log/nginx/access.log | tail -20
```

### Configure Per-Site Logging

Add to your site config:
```nginx
server {
    # ... other config ...
    
    access_log /var/log/nginx/site1.access.log;
    error_log /var/log/nginx/site1.error.log;
}
```

### Log Rotation

Nginx logs are automatically rotated by logrotate. Check the config:
```bash
cat /etc/logrotate.d/nginx
```

Default rotates weekly and keeps 4 weeks of logs.

---

## Common Issues & Solutions

### 1. "502 Bad Gateway" Error

**Cause:** Node.js app not running or crashed

**Fix:**
```bash
# Check if app is running
pm2 list

# Restart the app
pm2 restart your-app

# Check app logs
pm2 logs your-app
```

### 2. Permission Denied Errors

**Cause:** Wrong file permissions

**Fix:**
```bash
# Fix permissions
sudo chown -R www-data:www-data /var/www/yourdomain.com
sudo chmod -R 755 /var/www/yourdomain.com

# For deployer user setup
sudo chown -R deployer:deployer /home/deployer/apps/
```

### 3. SSL Certificate Errors

**Check certificate status:**
```bash
sudo certbot certificates
```

**Renew manually:**
```bash
sudo certbot renew
sudo systemctl reload nginx
```

### 4. "nginx: [emerg] bind() to 0.0.0.0:80 failed"

**Cause:** Another service using port 80

**Fix:**
```bash
# Find what's using port 80
sudo netstat -tlnp | grep :80

# Stop the conflicting service
sudo systemctl stop apache2  # or other service
sudo systemctl disable apache2
```

### 5. Site not loading after config change

**Always test before reloading:**
```bash
sudo nginx -t
```

If errors, fix them. If syntax OK:
```bash
sudo systemctl reload nginx
```

---

## Quick Commands Reference

```bash
# Start/Stop/Restart nginx
sudo systemctl start nginx
sudo systemctl stop nginx
sudo systemctl restart nginx

# Reload configuration (no downtime)
sudo systemctl reload nginx

# Check status
sudo systemctl status nginx

# Test configuration
sudo nginx -t

# View nginx version
nginx -v

# Enable/disable sites
sudo ln -s /etc/nginx/sites-available/site /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/site

# Edit configuration
sudo nano /etc/nginx/sites-available/your-site

# After any config change
sudo nginx -t && sudo systemctl reload nginx
```

---

## Next Steps

1. **Configure DNS** - Point your domains to your VPS IP
2. **Set up auto-deployment** - GitHub webhooks to automatically deploy
3. **Configure PM2** - Set up process management for your Node.js apps
4. **Set up monitoring** - Monitor nginx logs and app health
5. **Configure backups** - Backup your site files and databases

---

## Architecture Overview

```
Internet
    |
    v
Nginx (Port 80/443) ← SSL certificates (Certbot)
    |
    +---> site1.com (static build) → PM2 managed Next.js/React on port 3000
    +---> site2.com (React app) → PM2 managed on port 3001
    +---> site3.com (static HTML) → Direct nginx serve
    +---> api.domain.com (Node.js API) → PM2 managed on port 4000
    +---> n8n.domain.com → n8n (Port 5678)

GitHub Webhooks
    |
    +---> Deploy script → Pull → Build → Restart PM2 → Nginx serves
```

Nginx acts as the entry point, handling:
- SSL termination (HTTPS)
- Static file serving
- Reverse proxy to Node.js apps
- Load balancing (if needed)
- Security headers
- Compression (gzip)
