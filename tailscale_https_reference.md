# Tailscale HTTPS Reference  
### Proxmox, AdGuard Home, Jellyfin (No Caddy)

This document summarizes how to expose services on a Tailnet using **Tailscale Serve with HTTPS**, without Caddy, without DNS rewrites, and without exposing ports.

---

## Core Concepts (Read Once)

- **MagicDNS (`*.ts.net`) is authoritative**
  - You cannot override service names with custom DNS
  - Each hostname resolves to its **own node**
- **Tailscale Serve** is used to:
  - Terminate HTTPS
  - Issue and renew certificates automatically
  - Hide backend ports
- **Services should bind to `localhost`**
- **TLS is terminated by Tailscale**, not the application

---

## General Pattern

| Backend Type | Serve Command |
|-------------|---------------|
| HTTP backend | `tailscale serve --https=443 http://localhost:PORT` |
| HTTPS backend (valid cert) | `tailscale serve --https=443 https://localhost:PORT` |
| HTTPS backend (self-signed) | `tailscale serve --https=443 https+insecure://localhost:PORT` |

---

## Jellyfin (HTTP backend)

**Node:** `jellyfin`  
**Internal Port:** `8096`  
**Final URL:**  
```
https://jellyfin.terrier-duck.ts.net
```

### Steps

1. Ensure Jellyfin listens on localhost:
   ```
   127.0.0.1:8096
   ```

2. Enable HTTPS via Tailscale:

```bash
sudo tailscale serve --bg --https=443 http://localhost:8096
```

3. Verify:

```bash
tailscale serve status
```

---

## AdGuard Home (HTTP backend)

**Node:** `adguard`  
**Internal Port:** `80` (example)  
**Final URL:**  
```
https://adguard.terrier-duck.ts.net
```

### Steps

1. In AdGuard settings:
   - **Bind host:** `127.0.0.1`
   - **Disable HTTPS / TLS inside AdGuard**

2. Enable HTTPS via Tailscale:

```bash
sudo tailscale serve --bg --https=443 http://localhost:80
```

3. Verify:

```bash
tailscale serve status
```

---

## Proxmox VE (HTTPS backend, self-signed)

**Node:** `pve1`  
**Internal Port:** `8006`  
**Final URL:**  
```
https://pve1.terrier-duck.ts.net
```

### Why Proxmox is special

- Proxmox already uses HTTPS
- Its certificate is **self-signed**
- Tailscale must **skip upstream TLS verification**

### Steps

1. Enable HTTPS proxying with insecure upstream TLS:

```bash
sudo tailscale serve --bg --https=443 https+insecure://localhost:8006
```

2. Verify:

```bash
tailscale serve status
```

Expected output includes `https+insecure://`.

---

## Persistent systemd Units for Tailscale Serve

To ensure HTTPS access survives reboots, container restarts, and `tailscaled` restarts, define **systemd oneshot units** on each node that runs both `tailscaled` and the service being exposed.

> **Rule:** The unit file must live on the same host or container that owns the `*.ts.net` hostname.

---

### General systemd Pattern

All services follow the same structure:

- `Type=oneshot` with `RemainAfterExit=yes`
- Best-effort cleanup before start
- `--bg` so systemd does not hang
- Non-interactive shutdown using `--yes`

```ini
[Unit]
Description=Tailscale HTTPS Serve for <SERVICE>
After=network-online.target tailscaled.service
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes

# Best-effort cleanup (ignore error if none exists)
ExecStartPre=-/usr/bin/tailscale serve --https=443 off --yes

# Start HTTPS serving in background
ExecStart=/usr/bin/tailscale serve --bg --https=443 <BACKEND_URL>

# Cleanup on stop (non-interactive)
ExecStop=/usr/bin/tailscale serve --https=443 off --yes

[Install]
WantedBy=multi-user.target
```

---

### Jellyfin systemd Unit

**Node:** `jellyfin`

**File:** `/etc/systemd/system/tailscale-serve-jellyfin.service`

```ini
[Unit]
Description=Tailscale HTTPS Serve for Jellyfin
After=network-online.target tailscaled.service
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes

ExecStartPre=-/usr/bin/tailscale serve --https=443 off --yes
ExecStart=/usr/bin/tailscale serve --bg --https=443 http://localhost:8096
ExecStop=/usr/bin/tailscale serve --https=443 off --yes

[Install]
WantedBy=multi-user.target
```

---

### AdGuard Home systemd Unit

**Node:** `adguard`

**File:** `/etc/systemd/system/tailscale-serve-adguard.service`

```ini
[Unit]
Description=Tailscale HTTPS Serve for AdGuard Home
After=network-online.target tailscaled.service
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes

ExecStartPre=-/usr/bin/tailscale serve --https=443 off --yes
ExecStart=/usr/bin/tailscale serve --bg --https=443 http://localhost:80
ExecStop=/usr/bin/tailscale serve --https=443 off --yes

[Install]
WantedBy=multi-user.target
```

---

### Proxmox VE systemd Unit

**Node:** `pve1`

**File:** `/etc/systemd/system/tailscale-serve-proxmox.service`

```ini
[Unit]
Description=Tailscale HTTPS Serve for Proxmox VE
After=network-online.target tailscaled.service
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes

ExecStartPre=-/usr/bin/tailscale serve --https=443 off --yes
ExecStart=/usr/bin/tailscale serve --bg --https=443 https+insecure://localhost:8006
ExecStop=/usr/bin/tailscale serve --https=443 off --yes

[Install]
WantedBy=multi-user.target
```

---

### Enabling the Units

Run on each respective node:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now tailscale-serve-<service>.service
```

Verify:

```bash
systemctl status tailscale-serve-<service>.service
tailscale serve status
```

Expected state:

```
Active: active (exited)
```

---

## Verification Checklist

From any Tailnet client:

```bash
dig jellyfin.terrier-duck.ts.net
dig adguard.terrier-duck.ts.net
dig pve1.terrier-duck.ts.net
```

Each should resolve to its **own node IP**.

Test HTTPS:

```bash
curl -I https://jellyfin.terrier-duck.ts.net
curl -I https://adguard.terrier-duck.ts.net
curl -I https://pve1.terrier-duck.ts.net
```

Expected:
```
HTTP/2 200
```

---

## What NOT to Do (Important)

❌ Don’t use DNS rewrites for `*.ts.net`  
❌ Don’t use Let’s Encrypt with `*.ts.net`  
❌ Don’t enable HTTPS inside apps when using Serve  
❌ Don’t expose backend ports publicly  
❌ Don’t proxy cross-node services with Caddy under `*.ts.net`  

---

## When You *Would* Use Caddy Instead

Use Caddy only if you need:

- Public (non-Tailscale) access
- A domain you control
- Advanced routing, auth, or rate limiting
- One ingress for multiple nodes

For **pure Tailnet access**, Tailscale Serve is the correct tool.

---

## One-Line Summary

> Use idempotent systemd oneshot units with `--bg` and `--yes` on each Tailnet node to make `tailscale serve` HTTPS exposure fully persistent and reboot-safe.

