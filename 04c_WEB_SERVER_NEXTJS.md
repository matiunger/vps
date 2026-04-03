# Next.js Deployment on VPS - Server Setup Guide

Quick guide to deploy a Next.js app on your VPS with Nginx, PM2, SSL, and auto-deployment.

---

## 4. Deploy Your Next.js App

### Create App Directory

```bash
# Create project folder
sudo mkdir -p /var/www/myapp
cd /var/www/myapp

# Set ownership to deployer
sudo chown -R deployer:deployer /var/www/myapp
sudo chmod -R 755 /var/www/myapp
```

## 5. Configure Nginx as Reverse Proxy

### Create Nginx Config

```bash
sudo nano /etc/nginx/sites-available/myapp
```

Paste this configuration (replace `yourdomain.com`):
Change PORT 3001, 3002, etc. to your app's port.

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name yourdomain.com www.yourdomain.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
}
```

### Enable the Site

```bash
# Remove default site
sudo rm /etc/nginx/sites-enabled/default

# Enable your site
sudo ln -s /etc/nginx/sites-available/myapp /etc/nginx/sites-enabled/

# Test config
sudo nginx -t

# Restart Nginx
sudo service nginx restart
```

---

## 6. Install PM2 and Start App

### Install PM2

```bash
sudo npm install -g pm2
```

### Start App

**Always specify the port explicitly to avoid conflicts:**

```bash
cd /var/www/myapp/prod

# Start with PM2 (explicitly set port)
PORT=3000 pm2 start npm --name "myapp" -- start

# Save PM2 config (saves the running processes)
pm2 save

# Setup startup script
pm2 startup systemd
sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u deployer --hp /home/deployer
```

**What the startup script does:**

The `pm2 startup` command creates a systemd service that automatically starts your PM2 apps when the server reboots.

```bash
# Step 1: Generate the startup script
pm2 startup systemd
# This outputs a command for you to run (the next line)

# Step 2: Enable PM2 on boot
sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u deployer --hp /home/deployer
```

**How it works:**
- Creates a systemd service at `/etc/systemd/system/pm2-deployer.service`
- Registers PM2 to start automatically on server boot
- Uses the `deployer` user (not root) for security
- Loads the saved PM2 process list from `~/.pm2/dump.pm2`

**Verification:**
```bash
# Check if the service is enabled
sudo systemctl is-enabled pm2-deployer

# Output: enabled (means it will start on boot)

# View the startup service
sudo systemctl status pm2-deployer
```

**What happens on server reboot:**
1. Systemd starts the `pm2-deployer` service
2. PM2 loads the saved process list
3. All your apps (myapp, app2, etc.) start automatically
4. Your websites are back online without manual intervention

**Why always specify PORT explicitly:**

```bash
# Good - explicit port
PORT=3000 pm2 start npm --name "myapp" -- start

# Risky - relies on default port 3000
pm2 start npm --name "myapp" -- start
```

Setting `PORT=3000` explicitly:
- **Prevents conflicts** when running multiple apps
- **Makes configuration clear** - you know exactly which port is used
- **Matches Nginx config** - Nginx expects your app on port 3000
- **Avoids surprises** - some Next.js versions or configs might use different defaults

If you don't specify the port and try to run a second app, you'll get:
```
Error: Port 3000 is already in use
```

### PM2 Commands

```bash
# List apps
pm2 list

# View logs
pm2 logs myapp

# Restart
pm2 restart myapp

# Stop
pm2 stop myapp

# Delete
pm2 delete myapp
```

---

## 7. Setup SSL with Let's Encrypt

### Get Certificate

```bash
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com

# Follow prompts:
# - Enter email
# - Agree to terms
# - Choose whether to redirect HTTP to HTTPS (choose yes)
```

### Test Auto-Renewal

```bash
sudo certbot renew --dry-run
```

**Certbot automatically:**
- Updates your Nginx config with SSL
- Sets up auto-renewal
- Redirects HTTP to HTTPS

---

## 8. GitHub Actions Auto-Deployment

### Create GitHub Actions Workflow

Create `.github/workflows/deploy.yml` in your repo:

```yaml
name: Deploy to VPS

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
    
    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '20'
        cache: 'npm'
    
    - name: Install dependencies
      run: npm ci
    
    - name: Build application
      run: npm run build
    
    - name: Setup SSH
      uses: webfactory/ssh-agent@v0.9.1
      with:
        ssh-private-key: ${{ secrets.SSH_PRIVATE_KEY }}
    
    - name: Add server to known hosts
      run: |
        mkdir -p ~/.ssh
        ssh-keyscan -H ${{ secrets.SERVER_IP }} >> ~/.ssh/known_hosts
    
    - name: Deploy to server
      run: |
        echo "Deploying to VPS..."
        
        # Sync files (exclude large folders)
        rsync -avz --delete \
          --exclude 'node_modules' \
          --exclude '.env.local' \
          --exclude '.git' \
          --exclude '.next/cache' \
          -e "ssh" \
          ./ \
          ${{ secrets.SERVER_USER }}@${{ secrets.SERVER_IP }}:/var/www/myapp/
        
        # Run post-deploy commands
        ssh ${{ secrets.SERVER_USER }}@${{ secrets.SERVER_IP }} << 'EOF'
          cd /var/www/myapp
          npm ci --production
          npm run build
          pm2 restart myapp
        EOF
        
        echo "Deployment complete!"
```

---

## 9. Adding a Second Next.js App

To add another app (e.g., `app2` on port 3001):

### Changes Needed:

**Important:** Each app must run on a different port. App1 uses port 3000, so App2 must use a different port (e.g., 3001).

**1. Create Directory**
```bash
sudo mkdir -p /var/www/app2
sudo chown -R deployer:deployer /var/www/app2
```

**2. Deploy App2**
```bash
cd /var/www/app2
git clone https://github.com/username/repo2.git .
npm ci
npm run build
```

**3. Create Nginx Config for App2**

```bash
sudo nano /etc/nginx/sites-available/app2
```

```nginx
server {
    listen 80;
    server_name app2.yourdomain.com;

    location / {
        proxy_pass http://localhost:3001;  # Different port!
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```

**4. Enable Site**
```bash
sudo ln -s /etc/nginx/sites-available/app2 /etc/nginx/sites-enabled/
sudo nginx -t
sudo service nginx restart
```

**5. Start with PM2 on Port 3001**

```bash
cd /var/www/app2

# Start on port 3001 (explicitly set to avoid conflicts with app1 on 3000)
PORT=3001 pm2 start npm --name "app2" -- start

# Or use ecosystem file (recommended for multiple apps)
cat > ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'app2',
    cwd: '/var/www/app2',
    script: 'npm',
    args: 'start',
    env: {
      NODE_ENV: 'production',
      PORT: 3001
    }
  }]
}
EOF

pm2 start ecosystem.config.js
pm2 save
```

**6. Get SSL Certificate**
```bash
sudo certbot --nginx -d app2.yourdomain.com
```

### Summary of Changes for Multiple Apps:

| Component | App 1 | App 2 |
|-----------|-------|-------|
| Directory | `/var/www/myapp` | `/var/www/app2` |
| Nginx Config | `sites-available/myapp` | `sites-available/app2` |
| Port | 3000 | 3001 |
| PM2 Name | `myapp` | `app2` |
| Domain | `yourdomain.com` | `app2.yourdomain.com` |
| SSL | `certbot -d yourdomain.com` | `certbot -d app2.yourdomain.com` |

**GitHub Actions for App2:**

Create `.github/workflows/deploy-app2.yml`:

```yaml
name: Deploy App2 to VPS

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v4
    
    - uses: actions/setup-node@v4
      with:
        node-version: '20'
        cache: 'npm'
    
    - run: npm ci
    - run: npm run build
    
    - uses: webfactory/ssh-agent@v0.9.1
      with:
        ssh-private-key: ${{ secrets.SSH_PRIVATE_KEY }}
    
    - name: Deploy
      run: |
        rsync -avz --delete \
          --exclude 'node_modules' \
          --exclude '.env.local' \
          --exclude '.git' \
          --exclude '.next/cache' \
          -e "ssh" \
          ./ \
          ${{ secrets.SERVER_USER }}@${{ secrets.SERVER_IP }}:/var/www/app2/
        
        ssh ${{ secrets.SERVER_USER }}@${{ secrets.SERVER_IP }} << 'EOF'
          cd /var/www/app2
          npm ci --production
          npm run build
          pm2 restart app2
        EOF
```

---

## Quick Reference Commands

### Server Management

```bash
# Nginx
sudo nginx -t                    # Test config
sudo systemctl reload nginx      # Reload
sudo systemctl restart nginx     # Restart
sudo systemctl status nginx      # Check status

# PM2
pm2 list                        # List apps
pm2 logs myapp                   # View logs
pm2 restart myapp                # Restart app
pm2 stop myapp                   # Stop app
pm2 delete myapp                 # Remove app
pm2 monit                        # Monitor

# SSL
sudo certbot certificates        # List certificates
sudo certbot renew --dry-run     # Test renewal
```

### File Locations

```
/var/www/myapp/                  # App files
/etc/nginx/sites-available/      # Nginx configs
/etc/nginx/sites-enabled/        # Active configs
/var/log/nginx/                  # Nginx logs
~/.pm2/logs/                     # PM2 logs
```

---

## Troubleshooting

### 502 Bad Gateway

```bash
# Check if Next.js is running
pm2 list

# Check logs
pm2 logs myapp

# Test directly
curl http://localhost:3000

# Restart
pm2 restart myapp
```

### Permission Denied

```bash
# Fix ownership
sudo chown -R deployer:deployer /var/www/myapp
sudo chmod -R 755 /var/www/myapp
```

### Port Already in Use

```bash
# Find process
sudo lsof -i :3000

# Kill it
sudo kill -9 $(sudo lsof -t -i:3000)

# Restart PM2
pm2 restart myapp
```
