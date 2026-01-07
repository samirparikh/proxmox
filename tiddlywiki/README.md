To install Tiddlywiki:

mkdir -p ~/tiddlywiki && cd ~/tiddlywiki

Create `compose.yml` file:
```
services:
  tiddlywiki:
    build: .
    container_name: tiddlywiki
    restart: unless-stopped
    ports:
      - "8080:8080"
    volumes:
      - ./wiki-data:/wiki
    user: "1000:1000"
```

Create `Dockerfile`:
```
FROM node:22-slim
RUN npm install -g tiddlywiki
WORKDIR /wiki
CMD ["sh", "-c", "[ -f /wiki/tiddlywiki.info ] || tiddlywiki /wiki --init server; tiddlywiki /wiki --listen host=0.0.0.0"]
```

To pin npm and Tiddlywiki to specific versions:
```
FROM node:22.12.0-slim
RUN npm install -g tiddlywiki@5.3.6
WORKDIR /wiki
CMD ["sh", "-c", "[ -f /wiki/tiddlywiki.info ] || tiddlywiki /wiki --init server; tiddlywiki /wiki --listen host=0.0.0.0"]
```

so that:
```
~/tiddlywiki/
├── compose.yml
├── Dockerfile
└── wiki-data/
```

Start container:
```
docker compose up -d
```

The wiki will be accessible at `http://<container-ip>:8080` and all your wiki data lives in `./wiki-data/`.
