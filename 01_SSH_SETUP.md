This guide covers everything from generating your first key pair to configuring your machine for one-click logins.

---

# The Complete Guide to SSH Keys

SSH keys are a secure way to log into your server without a password. They consist of a **Public Key** (the lock) and a **Private Key** (the key).

## 1. Generate Your Key Pair

Open your terminal (or PowerShell on Windows) and run the following command. We use the **Ed25519** algorithm because it is more secure and efficient than older standards.

```bash
ssh-keygen -t ed25519 -C "your_email@example.com"

```

* **Save Location:** Press **Enter** to save it in the default folder (`~/.ssh/`).
* **Passphrase:** (Optional but recommended) Enter a "password for your key." This ensures that even if someone steals your computer, they can't use your key without this phrase.

---

## 2. Transfer the Public Key to Your Server

You need to move your **Public Key** (`id_ed25519.pub`) to the server. **Never share your private key.**

1. **Copy your key:** Run `cat ~/.ssh/id_ed25519.pub` and copy the resulting text.
2. **Log into your server console and add key:**

---

## 3. Log In Securely

Now, you can connect without being prompted for your account password:

```bash
ssh username@your_server_ip

```
Username is ussually **root**, but you can use any user you have created.

---

## 4. Pro Tip: Simplify with a Config File

Instead of typing `ssh username@123.45.67.89` every time, you can create a shortcut.

1. Create a file on your **local computer**: `nano ~/.ssh/config`
2. Add this block:
```text
Host myserver-root
    HostName 123.45.67.89
    User root
    IdentityFile ~/.ssh/id_ed25519

Host myserver
    HostName 123.45.67.89
    User deployer
    IdentityFile ~/.ssh/id_ed25519

```


3. Now, simply type: **`ssh myserver`**

---

## Quick Reference Table

| Component | File Name | Action |
| --- | --- | --- |
| **Private Key** | `id_ed25519` | Keep it safe on your laptop. |
| **Public Key** | `id_ed25519.pub` | Upload this to the server. |
| **Server List** | `authorized_keys` | Where the server stores allowed public keys. |

---

