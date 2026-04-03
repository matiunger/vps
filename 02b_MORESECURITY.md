# Advanced Security: Tailscale + Cloudflare

This guide layers two powerful security upgrades on top of the baseline in `02_VPS_SETUP.md`:

1. **Tailscale** — removes SSH from the public internet entirely
2. **Cloudflare** — hides your server's real IP and absorbs DDoS attacks

Together they reduce your server's public attack surface to almost zero.

---

## Why Bother?

After basic setup (UFW + fail2ban), your server still has:
- **Port 22 open publicly** → bots hammer it 24/7, fail2ban plays whack-a-mole
- **Your real IP visible** → anyone can bypass Cloudflare and hit your server directly, or DDoS the IP

After this guide:
- **Port 22 is gone from the internet** → only reachable via your private Tailscale network
- **Port 443 only accepts Cloudflare IPs** → your real IP is irrelevant to attackers

---

## Part 1: Tailscale

### What It Is

Tailscale creates a private mesh VPN between all your devices — laptop, phone, and server all get a private IP like `100.x.x.x`. You SSH using that private IP. No one else can reach port 22 at all.

**Free tier:** up to 100 devices, 3 users — more than enough for solo use.

---

### Step 1 — Create a Tailscale Account

Go to [tailscale.com](https://tailscale.com) and sign up (free). Log in with Google, GitHub, or Microsoft — no separate password needed.

---

### Step 2 — Install Tailscale on Your Devices First

Before installing on the server, connect your local machine and phone so you can verify it works.

**Mac:**
```bash
brew install tailscale
```
Or download from [tailscale.com/download](https://tailscale.com/download).

Open the Tailscale menu bar app and log in.

**iPhone/Android:**
Install the Tailscale app from the App Store / Play Store and log in with the same account.

---

### Step 3 — Generate a Server Auth Key

1. Go to [tailscale.com/admin/settings/keys](https://login.tailscale.com/admin/settings/keys)
2. Click **Generate auth key**
3. Check **Reusable** (useful if you ever rebuild the server)
4. Copy the key — it looks like `tskey-auth-...`

---

### Step 4 — Install Tailscale on the Server

```bash
curl -fsSL https://tailscale.com/install.sh | sh
```

Bring Tailscale up with your auth key and enable Tailscale SSH:

```bash
sudo tailscale up --authkey=tskey-auth-YOURKEY --ssh
```

The `--ssh` flag enables **Tailscale SSH** — you can SSH into the server using your Tailscale identity, no separate SSH key management needed (though your existing keys still work too).

Enable the service to start on boot:

```bash
sudo systemctl enable tailscaled
```

Check the server appears in your network:

```bash
tailscale status
```

You should see your server listed with a `100.x.x.x` IP.

---

### Step 5 — Verify SSH over Tailscale

**From your local machine**, open a new terminal and SSH using the Tailscale IP or hostname:

```bash
ssh deployer@100.x.x.x
# or by machine name:
ssh deployer@your-server-hostname
```

Do not close your current session until this works.

---

### Step 6 — Lock Down Public SSH

Once Tailscale SSH is confirmed working, remove port 22 from the public internet.

**If your VPS provider has a cloud-level firewall** (e.g. Hetzner, DigitalOcean, Linode), you have two layers to update:

| Layer | Where | Action |
|---|---|---|
| Cloud firewall | Provider console | Delete the TCP port 22 inbound rule |
| UFW | Inside the VPS | Commands below |

Also add **UDP port 41641** (WireGuard) to your cloud firewall inbound rules if it isn't there. Tailscale works without it (falls back to relay servers) but direct peer-to-peer connections require it.

**UFW commands on the server:**

```bash
# Remove the public SSH rule
sudo ufw delete allow 22/tcp

# Allow SSH only from the Tailscale interface
sudo ufw allow in on tailscale0 to any port 22 comment 'SSH via Tailscale only'

sudo ufw reload
sudo ufw status verbose
```

Port 22 is now invisible to the public internet. Fail2ban for SSH is now mostly redundant (keep it anyway — it also protects nginx).

---

### Step 7 — Update Your SSH Config (Local Machine)

Update `~/.ssh/config` on your local machine to use the Tailscale address:

```
Host myserver
    HostName 100.x.x.x        # your server's Tailscale IP
    User deployer
    IdentityFile ~/.ssh/id_ed25519
```

Or use the machine name if you've set MagicDNS in the Tailscale admin panel (it resolves hostnames automatically):

```
Host myserver
    HostName your-hostname.tail1234.ts.net
    User deployer
    IdentityFile ~/.ssh/id_ed25519
```

---

### Tailscale from Your Phone

Once the Tailscale app is running on your phone and connected to the same account, you can SSH from iOS/Android using an app like **Termius** or **iSH**. Your server is reachable at the `100.x.x.x` address from anywhere — home, coffee shop, mobile data — without any open ports.

---

## Part 2: Cloudflare

### What It Is

Cloudflare sits between your visitors and your server. Your DNS points to Cloudflare, not your server IP directly. Cloudflare proxies all traffic, so:
- Your real server IP is hidden
- DDoS attacks hit Cloudflare's network (which handles terabits/sec), not your VPS
- You get a global CDN for free

**Free tier:** includes DDoS protection, CDN, and proxying — everything below is free.

---

### Step 1 — Create a Cloudflare Account

Go to [cloudflare.com](https://cloudflare.com) and sign up (free).

---

### Step 2 — Add Your Domain to Cloudflare

1. In the Cloudflare dashboard, click **Add a Site**
2. Enter your domain (e.g. `yourdomain.com`)
3. Choose the **Free** plan
4. Cloudflare will scan your existing DNS records — review them and click **Continue**

---

### Step 3 — Update Your Domain's Nameservers

Cloudflare will give you two nameservers like:
```
aria.ns.cloudflare.com
bob.ns.cloudflare.com
```

Go to your domain registrar (Namecheap, GoDaddy, Google Domains, etc.) and replace the existing nameservers with these two. Propagation takes a few minutes to a few hours.

---

### Step 4 — Configure DNS Records in Cloudflare

In Cloudflare's DNS tab, create/confirm your A records:

| Type | Name | Content | Proxy |
|------|------|---------|-------|
| A | `@` | `your-server-ip` | Proxied (orange cloud) |
| A | `www` | `your-server-ip` | Proxied (orange cloud) |
| A | `staging` | `your-server-ip` | Proxied (orange cloud) |

The **orange cloud** = Cloudflare is proxying the traffic (your real IP is hidden).
A **grey cloud** = DNS only, your real IP is exposed — avoid this for public-facing records.

---

### Step 5 — Set SSL/TLS Mode to "Full (Strict)"

1. In Cloudflare dashboard → **SSL/TLS** → **Overview**
2. Set encryption mode to **Full (Strict)**

This means:
- Cloudflare to visitor: HTTPS (Cloudflare's certificate)
- Cloudflare to your server: HTTPS (your Let's Encrypt cert)

Never use "Flexible" — it sends traffic from Cloudflare to your server unencrypted.

---

### Step 6 — Restrict Port 443 to Cloudflare IPs Only

This is the key step. Your server should only accept HTTPS traffic from Cloudflare's IP ranges — not from anyone else who might discover your real IP.

**Hetzner console (cloud firewall):**

Delete the existing TCP port 443 inbound rule that allows from Any IPv4 / Any IPv6, then add one inbound rule per Cloudflare IP range (TCP port 443). This blocks traffic at the network level before it even reaches your server. It's tedious (22 rules) but adds a second layer of defense on top of UFW.

Cloudflare IPv4 ranges to add:
```
173.245.48.0/20
103.21.244.0/22
103.22.200.0/22
103.31.4.0/22
141.101.64.0/18
108.162.192.0/18
190.93.240.0/20
188.114.96.0/20
197.234.240.0/22
198.41.128.0/17
162.158.0.0/15
104.16.0.0/13
104.24.0.0/14
172.64.0.0/13
131.0.72.0/22
```

Cloudflare IPv6 ranges to add:
```
2400:cb00::/32
2606:4700::/32
2803:f800::/32
2405:b500::/32
2405:8100::/32
2a06:98c0::/29
2c0f:f248::/32
```

**VPS (UFW):**

Run this single command to add all Cloudflare IP ranges and remove the general port 443 rule in one go (verify ranges at [cloudflare.com/ips-v4](https://www.cloudflare.com/ips-v4/) and [cloudflare.com/ips-v6](https://www.cloudflare.com/ips-v6/)):

```bash
for ip in 173.245.48.0/20 103.21.244.0/22 103.22.200.0/22 103.31.4.0/22 141.101.64.0/18 108.162.192.0/18 190.93.240.0/20 188.114.96.0/20 197.234.240.0/22 198.41.128.0/17 162.158.0.0/15 104.16.0.0/13 104.24.0.0/14 172.64.0.0/13 131.0.72.0/22 2400:cb00::/32 2606:4700::/32 2803:f800::/32 2405:b500::/32 2405:8100::/32 2a06:98c0::/29 2c0f:f248::/32; do sudo ufw allow from $ip to any port 443; done && sudo ufw delete allow 443/tcp && sudo ufw reload && sudo ufw status verbose
```

Port 443 is now only reachable from Cloudflare. Anyone hitting your raw IP on 443 gets blocked.

> **Note:** Cloudflare occasionally updates their IP ranges. Check [cloudflare.com/ips-v4](https://www.cloudflare.com/ips-v4/) and [cloudflare.com/ips-v6](https://www.cloudflare.com/ips-v6/) and update these rules if they change. You can automate this with a cron script if you want.

---

### Step 7 — Restrict Port 80 to Cloudflare IPs Only

Certbot renews certificates via HTTP on port 80 through Cloudflare, so port 80 needs to stay open — but only for Cloudflare IPs, same as port 443.

**Hetzner console (cloud firewall):**

Delete the existing TCP port 80 inbound rule that allows from Any IPv4 / Any IPv6, then add one inbound rule per Cloudflare IP range (TCP port 80) — same ranges as Step 6.

**VPS (UFW):**

```bash
for ip in 173.245.48.0/20 103.21.244.0/22 103.22.200.0/22 103.31.4.0/22 141.101.64.0/18 108.162.192.0/18 190.93.240.0/20 188.114.96.0/20 197.234.240.0/22 198.41.128.0/17 162.158.0.0/15 104.16.0.0/13 104.24.0.0/14 172.64.0.0/13 131.0.72.0/22 2400:cb00::/32 2606:4700::/32 2803:f800::/32 2405:b500::/32 2405:8100::/32 2a06:98c0::/29 2c0f:f248::/32; do sudo ufw allow from $ip to any port 80; done && sudo ufw delete allow 80/tcp && sudo ufw reload && sudo ufw status verbose
```

---

## Final Firewall State

After both parts, your UFW rules should look like this:

```
Status: active

To                         Action      From
--                         ------      ----
22 on tailscale0           ALLOW       Anywhere          # SSH via Tailscale only
443                        ALLOW       173.245.48.0/20   # Cloudflare
443                        ALLOW       103.21.244.0/22   # Cloudflare
... (all other CF ranges)
80                         ALLOW       173.245.48.0/20   # Cloudflare (or closed if DNS challenge)
... (all other CF ranges)
Anywhere on tailscale0     ALLOW       Anywhere          # Tailscale internal traffic
```

Your server has **no ports open to arbitrary internet traffic**. SSH is private, HTTPS is Cloudflare-only.

---

## Verification Checklist

```bash
# Tailscale running
tailscale status

# Confirm SSH works over Tailscale
ssh deployer@100.x.x.x

# Confirm SSH is NOT reachable on public IP (should time out or refuse)
ssh deployer@YOUR-PUBLIC-IP   # should fail

# UFW rules look correct
sudo ufw status verbose

# Check Cloudflare is proxying (should show Cloudflare IP, not yours)
curl -s https://yourdomain.com -I | grep -i "server\|cf-ray"
# You should see: server: cloudflare and a cf-ray header

# Verify your real IP is not reachable on 443
curl -k https://YOUR-PUBLIC-IP   # should fail or be blocked
```

---

## Part 3: GitHub Actions Deployment (Pull Model)

After locking SSH to Tailscale-only, GitHub Actions runners can no longer SSH into your server — they're external machines with no Tailscale access.

The solution is to **flip the direction**: instead of GitHub pushing to your server, your server pulls from GitHub. The server listens for a webhook notification, then runs `git pull` itself. No inbound SSH needed from GitHub at all.

---

### How It Works

```
GitHub push → GitHub sends webhook → your server receives it → server runs git pull + restart
```

The webhook is a plain HTTPS POST to a small script running on your server. Since it goes through Cloudflare on port 443, it's already covered by your existing firewall setup.

---

### Step 1 — Create the Webhook Script

This is a small Node.js script that listens for GitHub webhook events and runs your deploy commands.

Create the file:

```bash
mkdir -p /home/deployer/tools
nano /home/deployer/tools/webhook.js
```

Paste the following:

```js
import http from 'http'
import crypto from 'crypto'
import { execSync } from 'child_process'

const SECRET = process.env.WEBHOOK_SECRET
const PORT = process.env.WEBHOOK_PORT || 9000

// Map of repo name → deploy command
const DEPLOY_COMMANDS = {
  'yourrepo': 'cd /home/deployer/apps/public/yourdomain.com && git pull && npm install --production && pm2 restart yourdomain',
  'another-repo': 'cd /home/deployer/apps/public/anotherdomain.com && git pull && pm2 restart anotherdomain',
}

function verifySignature(payload, signature) {
  const hmac = crypto.createHmac('sha256', SECRET)
  const digest = 'sha256=' + hmac.update(payload).digest('hex')
  return crypto.timingSafeEqual(Buffer.from(digest), Buffer.from(signature))
}

const server = http.createServer((req, res) => {
  if (req.method !== 'POST' || req.url !== '/webhook') {
    res.writeHead(404)
    res.end()
    return
  }

  let body = ''
  req.on('data', chunk => body += chunk)
  req.on('end', () => {
    const signature = req.headers['x-hub-signature-256']

    if (!signature || !verifySignature(body, signature)) {
      console.log('Invalid signature — rejected')
      res.writeHead(401)
      res.end('Unauthorized')
      return
    }

    const event = req.headers['x-github-event']
    if (event !== 'push') {
      res.writeHead(200)
      res.end('Ignored')
      return
    }

    const payload = JSON.parse(body)
    const branch = payload.ref  // e.g. "refs/heads/main"
    const repo = payload.repository.name

    // Only deploy on pushes to main
    if (branch !== 'refs/heads/main') {
      res.writeHead(200)
      res.end('Not main branch, ignored')
      return
    }

    const cmd = DEPLOY_COMMANDS[repo]
    if (!cmd) {
      res.writeHead(200)
      res.end('No deploy configured for this repo')
      return
    }

    console.log(`Deploying ${repo}...`)
    res.writeHead(200)
    res.end('Deploying')

    try {
      execSync(cmd, { stdio: 'inherit' })
      console.log(`Deployed ${repo} successfully`)
    } catch (err) {
      console.error(`Deploy failed for ${repo}:`, err.message)
    }
  })
})

server.listen(PORT, '127.0.0.1', () => {
  console.log(`Webhook server listening on port ${PORT}`)
})
```

> The server binds to `127.0.0.1` (localhost only) — it's never exposed directly to the internet. Nginx proxies to it.

---

### Step 2 — Configure the Deploy Commands

Edit `DEPLOY_COMMANDS` at the top of the script to match your repos and apps:

```js
const DEPLOY_COMMANDS = {
  'my-site': 'cd /home/deployer/apps/public/mysite.com && git pull && pm2 restart mysite',
  'my-nextjs-app': 'cd /home/deployer/apps/public/nextjs.com && git pull && npm install --production && npm run build && pm2 restart nextjs',
}
```

The key is the **GitHub repository name** (not the full URL, just the name after the `/`).

---

### Step 3 — Create a Webhook Secret

Generate a strong random secret:

```bash
openssl rand -hex 32
```

Copy the output. Store it in your secrets file:

```bash
nano /home/deployer/secrets/webhook.env
```

```
WEBHOOK_SECRET=your_generated_secret_here
WEBHOOK_PORT=9000
```

```bash
chmod 600 /home/deployer/secrets/webhook.env
```

---

### Step 4 — Run the Webhook Server with PM2

```bash
cd /home/deployer/tools
pm2 start webhook.js --name webhook --env-file /home/deployer/secrets/webhook.env
pm2 save
```

Verify it's running:

```bash
pm2 status
pm2 logs webhook
```

---

### Step 5 — Expose the Webhook via Nginx

Add a location block to your nginx config so the webhook is reachable at `https://yourdomain.com/webhook`. You can add this to any existing site config, or create a dedicated one.

Edit the relevant file in `/etc/nginx/sites-available/`:

```nginx
server {
    listen 443 ssl;
    server_name yourdomain.com;

    # ... your existing SSL and site config ...

    location /webhook {
        proxy_pass http://127.0.0.1:9000/webhook;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 30s;
    }
}
```

Test and reload nginx:

```bash
sudo nginx -t
sudo systemctl reload nginx
```

---

### Step 6 — Add the Webhook in GitHub

For each repository:

1. Go to your repo → **Settings** → **Webhooks** → **Add webhook**
2. **Payload URL:** `https://yourdomain.com/webhook`
3. **Content type:** `application/json`
4. **Secret:** paste the secret you generated in Step 3
5. **Which events:** select **Just the push event**
6. Click **Add webhook**

GitHub will send a test ping — check `pm2 logs webhook` to confirm it was received.

---

### Step 7 — Make Sure the Server Can Pull from GitHub

The server needs read access to your repos. Since you don't want to store SSH keys in the repo, use a **GitHub deploy key** — a read-only SSH key scoped to a single repository.

On your server, generate a deploy key:

```bash
ssh-keygen -t ed25519 -C "deploy@yourserver" -f /home/deployer/.ssh/deploy_key -N ""
```

Copy the public key:

```bash
cat /home/deployer/.ssh/deploy_key.pub
```

In GitHub: repo → **Settings** → **Deploy keys** → **Add deploy key** → paste the public key. Leave "Allow write access" unchecked.

Configure SSH to use this key for GitHub:

```bash
nano /home/deployer/.ssh/config
```

```
Host github.com
    IdentityFile /home/deployer/.ssh/deploy_key
    IdentitiesOnly yes
```

Test it:

```bash
ssh -T git@github.com
# Should say: Hi yourrepo! You've successfully authenticated...
```

Make sure your repo remote uses SSH (not HTTPS):

```bash
cd /home/deployer/apps/public/yourdomain.com
git remote -v
# Should show: git@github.com:yourusername/yourrepo.git

# If it shows https://, switch it:
git remote set-url origin git@github.com:yourusername/yourrepo.git
```

---

### How to Deploy

Push to `main` on GitHub. The webhook fires, the server pulls, restarts. Done.

```bash
# On your local machine:
git push origin main
# → GitHub notifies your server
# → server runs git pull + pm2 restart
# → site is updated within seconds
```

To deploy a staging branch, add a second location and PM2 process pointing at `refs/heads/staging`.

---

### Troubleshooting

```bash
# Watch webhook logs in real time
pm2 logs webhook

# Test the webhook manually (replace with your secret)
curl -X POST https://yourdomain.com/webhook \
  -H "Content-Type: application/json" \
  -H "X-GitHub-Event: push" \
  -H "X-Hub-Signature-256: sha256=INVALID" \
  -d '{}'
# Should return 401 Unauthorized (signature check working)

# Check GitHub delivery logs
# GitHub repo → Settings → Webhooks → your webhook → Recent Deliveries
# Shows exact payload sent and your server's response
```

---

## Ongoing Maintenance

- **Tailscale** — updates itself automatically. Check `tailscale status` occasionally.
- **Cloudflare IPs** — check [cloudflare.com/ips](https://www.cloudflare.com/ips/) a few times a year and update UFW rules if the ranges change.
- **SSL certs** — certbot auto-renews via a systemd timer. Verify with `sudo certbot renew --dry-run`.
- **Webhook server** — runs under PM2, restarts automatically on crash and on server reboot (after `pm2 save`).
