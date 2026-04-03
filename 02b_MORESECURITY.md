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

## Part 3: Updating GitHub Actions for Tailscale

The workflows in `04c_WEB_SERVER_NEXTJS.md` use direct SSH (`ssh-agent` + `rsync`) to deploy. Since SSH is now locked to Tailscale, GitHub Actions runners — which are external machines — can no longer reach your server.

The fix is the official **Tailscale GitHub Action**, which connects the runner to your Tailscale network before the SSH step. The rest of the workflow stays the same.



---

### Step 1 — Create an ACL Tag for GitHub Actions

In the Tailscale admin panel → **Access Controls**, add a tag for GitHub runners:

```json
"tagOwners": {
		"tag:github-actions": [],
		"tag:munger-vps":     [],
	},

"grants": [
		// Allow all connections.
		// Comment this section out if you want to define specific restrictions.
		{"src": ["*"], "dst": ["*"], "ip": ["*"]},
		{
			"src": ["tag:github-actions"],
			"dst": ["tag:munger-vps"],
			"ip":  ["*"],
		},
		// Allow users in "group:example" to access "tag:example", but only from
		// devices that are running macOS and have enabled Tailscale client auto-updating.
		// {"src": ["group:example"], "dst": ["tag:example"], "ip": ["*"], "srcPosture":["posture:autoUpdateMac"]},
	],

"ssh": [
		// Allow all users to SSH into their own devices in check mode.
		// Comment this section out if you want to define specific restrictions.
		{
			"action": "check",
			"src":    ["autogroup:member"],
			"dst":    ["autogroup:self"],
			"users":  ["autogroup:nonroot", "root"],
		},
		{
			"action": "accept",
			"src":    ["autogroup:admin"],
			"dst":    ["tag:munger-vps"],
			"users":  ["autogroup:nonroot", "root"],
		},
		{
			"action": "accept",
			"src":    ["tag:github-actions"],
			"dst":    ["tag:munger-vps"],
			"users":  ["autogroup:nonroot", "root"],
		},
	],
```

This scopes the OAuth client to ephemeral devices (the runner joins Tailscale temporarily for each deploy and then disappears).

---

### Step 2 — Create a Tailscale OAuth Client

1. Go to [tailscale.com/admin/settings/oauth](https://login.tailscale.com/admin/settings/oauth)
2. Click **Generate OAuth client**
3. Under **Scopes**,select:
  **Devices → Write** (Select tag)
  **Auth Keys  → Write** (Select tag)
4. Copy the **Client ID** and **Client Secret**

---

### Step 3 — Add GitHub Secrets

In your GitHub repo → **Settings** → **Secrets and variables** → **Actions**, add:

| Secret | Value |
|---|---|
| `TAILSCALE_OAUTH_CLIENT_ID` | OAuth client ID from Step 2 |
| `TAILSCALE_OAUTH_SECRET` | OAuth secret from Step 2 |
| `SERVER_IP` | **Update the value** to your server's Tailscale IP (`100.x.x.x`) |
| `SERVER_USER` | `deployer` |
| `SSH_PRIVATE_KEY` | Your deploy SSH private key |

Just update the value of the existing `SERVER_IP` secret — no need to rename it or change the workflow references.

---

### Step 4 — Update the Workflow

Replace the workflow from `04c_WEB_SERVER_NEXTJS.md` with this updated version. The only change from the original is the **Connect to Tailscale** step — everything else stays the same:

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

    - name: Connect to Tailscale
      uses: tailscale/github-action@v4
      with:
        oauth-client-id: ${{ secrets.TAILSCALE_OAUTH_CLIENT_ID }}
        oauth-secret: ${{ secrets.TAILSCALE_OAUTH_SECRET }}
        tags: tag:github-actions
        version: latest

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
        rsync -avz --delete \
          --exclude 'node_modules' \
          --exclude '.env.local' \
          --exclude '.git' \
          --exclude '.next/cache' \
          -e "ssh" \
          ./ \
          ${{ secrets.SERVER_USER }}@${{ secrets.SERVER_IP }}:/var/www/myapp/

        ssh ${{ secrets.SERVER_USER }}@${{ secrets.SERVER_IP }} << 'EOF'
          cd /var/www/myapp
          npm ci --production
          pm2 restart myapp
        EOF

        echo "Deployment complete!"
```

For a second app, do the same — reuse the same `TAILSCALE_OAUTH_CLIENT_ID`, `TAILSCALE_OAUTH_SECRET`, and `SERVER_IP` secrets, just change the rsync target path and pm2 app name.

---

### How It Works

```
git push → GitHub runner starts → runner joins Tailscale network
→ runner SSHes to server via Tailscale IP → rsync + pm2 restart
→ runner leaves Tailscale (ephemeral device, auto-removed)
```

The runner is only on your Tailscale network for the duration of the deploy. It's automatically removed afterwards — no permanent devices accumulate in your Tailscale admin.

---

### Troubleshooting

```bash
# Verify the runner connected (check Tailscale admin during a deploy run)
# You should see a device like "github-runner-xxxxx" appear temporarily

# If SSH times out, confirm the Tailscale step succeeded in the Actions log
# and that SERVER_IP matches your server's 100.x.x.x address
tailscale status  # run on server to confirm its Tailscale IP
```