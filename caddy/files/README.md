# Caddy Reverse Proxy with Porkbun DNS

Custom Caddy build with Porkbun DNS provider for DNS-01 ACME challenges. Used to proxy Tailscale services with custom domain names and automatic HTTPS.

## Prerequisites

- Docker and Docker Compose
- Porkbun domain with API access enabled
- Services accessible via Tailscale

## Setup

1. **Copy and configure the environment file:**

   ```bash
   cp porkbun.env.example porkbun.env
   # Edit porkbun.env with your actual API credentials
   ```

2. **Edit the Caddyfile:**

   - Update the email address
   - Adjust service hostnames and ports as needed

3. **Create DNS records in Porkbun:**

   | Type  | Host     | Answer                       |
   |-------|----------|------------------------------|
   | CNAME | adguard  | caddy.terrier-duck.ts.net    |
   | CNAME | pve1     | caddy.terrier-duck.ts.net    |
   | CNAME | jellyfin | caddy.terrier-duck.ts.net    |

4. **Enable API access for your domain in Porkbun:**

   Domain Management → your domain → API Access → Enable

## Usage

```bash
# Build and start
docker compose up -d

# View logs
docker compose logs -f

# Rebuild after Dockerfile changes
docker compose build --no-cache
docker compose up -d

# Stop
docker compose down
```

## Files

- `Dockerfile` - Multi-stage build for Caddy with Porkbun DNS plugin
- `docker-compose.yml` - Container orchestration
- `Caddyfile` - Reverse proxy configuration
- `porkbun.env` - API credentials (not in git)
- `porkbun.env.example` - Template for credentials

## Adding New Services

1. Add a CNAME record in Porkbun pointing to your Caddy Tailscale hostname
2. Add a new block to the Caddyfile:

   ```caddyfile
   newservice.winchser.com {
       import tls_porkbun
       reverse_proxy http://newservice.terrier-duck.ts.net:PORT
   }
   ```

3. Reload Caddy:

   ```bash
   docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile
   ```
