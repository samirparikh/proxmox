FROM golang:1.24-alpine AS builder

RUN go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest

RUN xcaddy build \
    --with github.com/caddy-dns/porkbun

FROM alpine:latest

RUN apk add --no-cache ca-certificates tzdata

COPY --from=builder /go/caddy /usr/bin/caddy

RUN mkdir -p /etc/caddy /data /config

EXPOSE 80 443 443/udp 2019

ENTRYPOINT ["caddy"]
CMD ["run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
