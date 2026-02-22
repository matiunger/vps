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

## Hosting Static Websites

### Create Site Directory

```bash
# Create directory for your site
sudo mkdir -p /var/www/yourdomain.com/html

# Set correct ownership
sudo chown -R $USER:$USER /var/www/yourdomain.com/html

# Set correct permissions
sudo chmod -R 755 /var/www/yourdomain.com
```

### Create Nginx Config

```bash
sudo nano /etc/nginx/sites-available/yourdomain.com
```

Basic static site config:
```nginx
server {
    listen 80;
    listen [::]:80;
    
    server_name yourdomain.com www.yourdomain.com;
    
    root /var/www/yourdomain.com/html;
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
# Create symlink to enable the site
sudo ln -s /etc/nginx/sites-available/yourdomain.com /etc/nginx/sites-enabled/

# Test configuration
sudo nginx -t

# Reload nginx
sudo systemctl reload nginx
```

### Deploy Your Static Files

```bash
# Example: copy your built site
cp -r /path/to/your/dist/* /var/www/yourdomain.com/html/

# Or if using the deployer user structure:
# ln -s /home/deployer/apps/public/yourdomain.com/build /var/www/yourdomain.com/html
```

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

```
/home/deployer/apps/
├── public/
│   ├── site1.com/          # Next.js app
│   ├── site2.com/          # React app
│   └── site3.com/          # Static site
├── private/
│   └── admin.mydomain.com/
└── n8n/
```

### Example: Multiple Sites

**site1.com** (Next.js on port 3000):
```nginx
server {
    listen 443 ssl http2;
    server_name site1.com;
    
    ssl_certificate /etc/letsencrypt/live/site1.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/site1.com/privkey.pem;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

**site2.com** (React on port 3001):
```nginx
server {
    listen 443 ssl http2;
    server_name site2.com;
    
    ssl_certificate /etc/letsencrypt/live/site2.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/site2.com/privkey.pem;
    
    location / {
        proxy_pass http://localhost:3001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

**site3.com** (Static files):
```nginx
server {
    listen 443 ssl http2;
    server_name site3.com;
    
    ssl_certificate /etc/letsencrypt/live/site3.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/site3.com/privkey.pem;
    
    root /var/www/site3.com/html;
    index index.html;
    
    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

### Enable All Sites

```bash
# Create symlinks for all sites
sudo ln -s /etc/nginx/sites-available/site1.com /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/site2.com /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/site3.com /etc/nginx/sites-enabled/

# Test and reload
sudo nginx -t
sudo systemctl reload nginx
```

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
