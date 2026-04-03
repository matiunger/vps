443 only receive from Cloudflare IPs
22 SSH only receive from Tailscale subet
SSH key ofc

# Hetzner VPS Setup Guide

> **This file is a Claude Code setup prompt. When you feed this file to Claude Code, it must follow the instructions in the CLAUDE INSTRUCTIONS block below before doing anything else.**

---

## CLAUDE INSTRUCTIONS

Before executing any setup steps, ask the user the following questions **one at a time** and wait for each answer:

1. **Username:** "What username do you want to create on the server?"

2. **SSH public key:** "Please paste your SSH public key (or multiple keys, one per line). This will be the only way to log into the server."

3. **Tailscale:** "Do you want to set up Tailscale for private network access from your phone and computer? (yes/no)"
   - If yes: "Please paste your Tailscale auth key. You can generate one at https://login.tailscale.com/admin/settings/keys — use a reusable auth key if you plan to add multiple devices."

Once you have the answers, proceed with the setup steps below. Substitute `<USERNAME>`, `<SSH_PUBLIC_KEY>` and Tailscale steps accordingly. Skip Section 9 (Tailscale) entirely if the user said no.

---

## System Baseline

- **OS:** Ubuntu 24.04 LTS
- **Hostname:** set via Hetzner console or `hostnamectl set-hostname <your-hostname>`

---

## 1. Initial Package Install

```bash
apt update && apt upgrade -y
apt install -y fail2ban curl git vim ufw
```

---

## 2. Create the Admin User

```bash
useradd -m -s /bin/bash -G sudo,adm <USERNAME>
```

Set home directory permissions:

```bash
chmod 750 /home/<USERNAME>
```

---

## 3. SSH Key Authentication Setup

Create the `.ssh` directory with strict permissions:

```bash
mkdir -p /home/<USERNAME>/.ssh
chmod 700 /home/<USERNAME>/.ssh
chown <USERNAME>:<USERNAME> /home/<USERNAME>/.ssh
```

Write the authorized_keys file using the key(s) the user provided:

```bash
cat > /home/<USERNAME>/.ssh/authorized_keys << 'EOF'
<SSH_PUBLIC_KEY>
EOF
```

Lock down the file:

```bash
chmod 600 /home/<USERNAME>/.ssh/authorized_keys
chown <USERNAME>:<USERNAME> /home/<USERNAME>/.ssh/authorized_keys
```

---

## 4. Sudo Access (Passwordless)

```bash
echo "<USERNAME> ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/<USERNAME>
chmod 440 /etc/sudoers.d/<USERNAME>
```

---

## 5. SSH Server Hardening

Replace `/etc/ssh/sshd_config` with the following:

```bash
cat > /etc/ssh/sshd_config << 'EOF'
# Authentication
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
KbdInteractiveAuthentication no
PermitEmptyPasswords no
StrictModes yes

# Session limits
LoginGraceTime 30
MaxAuthTries 10
MaxSessions 5
ClientAliveInterval 300
ClientAliveCountMax 2

# Restrict access to a single user
AllowUsers <USERNAME>

# Disable unused features
AllowAgentForwarding no
AllowTcpForwarding no
X11Forwarding no
PrintMotd no

# Logging
LogLevel VERBOSE
UsePAM yes

# SFTP subsystem
Subsystem sftp /usr/lib/openssh/sftp-server
EOF
```

Restart SSH (keep your current session open until verified):

```bash
systemctl restart ssh
```

**Verify login works** in a new terminal before closing the current session.

---

## 6. Fail2ban Configuration

Create `/etc/fail2ban/jail.local`:

```bash
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 5
ignoreip = 127.0.0.1/8

[sshd]
enabled  = true
port     = ssh
filter   = sshd
maxretry = 3
bantime  = 24h
ignoreip = 127.0.0.1/8 ::1
EOF
```

> **Note:** If you have a static home/office IP, add it to `ignoreip` to avoid locking yourself out.

Enable and start fail2ban:

```bash
systemctl enable fail2ban
systemctl restart fail2ban
```

Verify the jail is active:

```bash
fail2ban-client status sshd
```

---

## 7. Unattended Security Upgrades

```bash
apt install -y unattended-upgrades
dpkg-reconfigure --priority=low unattended-upgrades
```

Ensure daily checks are enabled:

```bash
cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
```

---

## 8. Firewall (UFW)

```bash
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH'
ufw --force enable
ufw status verbose
```

> If Tailscale is being set up (Section 9), also run:
> ```bash
> ufw allow in on tailscale0
> ```

---

## 9. Tailscale (skip if user said no)

Install Tailscale:

```bash
curl -fsSL https://tailscale.com/install.sh | sh
```

Bring up Tailscale using the auth key the user provided:

```bash
tailscale up --authkey=<TAILSCALE_AUTH_KEY> --ssh
```

The `--ssh` flag enables **Tailscale SSH**, which means you can also SSH into this server over the Tailscale network without needing to expose port 22 publicly at all.

Enable and verify:

```bash
systemctl enable tailscaled
tailscale status
```

Tailscale will assign the server a private IP (e.g., `100.x.x.x`). You can then SSH via:

```bash
ssh <USERNAME>@<tailscale-ip>
# or by hostname:
ssh <USERNAME>@<hostname>
```

**Connect your devices:**
- **iPhone/Android:** Install the Tailscale app from the App Store / Play Store and log in with the same Tailscale account.
- **Mac/PC:** Install from https://tailscale.com/download and log in with the same account.

All devices on the same Tailscale account form a private network — no open ports required.

**Optional: lock down public SSH once Tailscale is working**

Once you've confirmed SSH over Tailscale works from your devices, you can remove the public SSH rule and only allow SSH from the Tailscale interface:

```bash
ufw delete allow 22/tcp
ufw allow in on tailscale0 to any port 22 comment 'SSH via Tailscale only'
ufw reload
```

> Only do this after confirming Tailscale SSH works, or you will lock yourself out.

---

## 10. How to Connect via SSH

**Direct (public IP):**
```bash
ssh <USERNAME>@<server-ip>
```

**Via Tailscale (if enabled):**
```bash
ssh <USERNAME>@<tailscale-ip-or-hostname>
```

- Root login is **disabled**.
- Password login is **disabled** — SSH key required.
- Only `<USERNAME>` is allowed to SSH in.
- Fail2ban bans an IP after **3 failed SSH attempts** for **24 hours**.

---

## 11. Verification Checklist

```bash
# SSH service running
systemctl status ssh

# Fail2ban running and sshd jail active
systemctl status fail2ban
fail2ban-client status

# UFW active
ufw status verbose

# Tailscale (if installed)
tailscale status

# User and groups correct
id <USERNAME>
# Expected: uid=1000(<USERNAME>) gid=1000(<USERNAME>) groups=...,4(adm),27(sudo),...

# SSH config test (dry run)
sshd -t
```

---

## Notes

- The `adm` group membership grants read access to system logs (`/var/log`).
- `qemu-guest-agent` is installed by default on Hetzner VPS images — no action needed.
- This script runs as root — ensure `<USERNAME>` has the necessary permissions for resources they'll manage.