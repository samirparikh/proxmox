### To install Vaultwarden:

1.  Install Tailscale

```
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up
```

2.  Prepare environment
```
mkdir -p vaultwarden/vw-data
```

3.  Create vaultwarden/compose.yml

4.  Run `docker-compose`
```
cd vaultwarden
docker compose up -d && docker compose logs -f
```
5.  Create a `CNAME` record with your registrar pointing `vaultwarden.example.com` to `hostname.tailnet.ts.net`.

6.  Update `/etc/caddy/Caddyfile` with
```
vaultwarden.example.com {
        import common
        reverse_proxy http://hostname.tailnet.ts.net:8080
}
```
