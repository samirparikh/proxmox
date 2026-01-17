Linkding installation instructions on minimized Ubuntu 24.04 VM on Proxmox:

As `root`:

1. Install docker using https://github.com/samirparikh/proxmox/blob/main/install-docker-debian.sh

2. `usermod -aG docker <USER>`

As `<USER>`:

1. `mkdir -p linkding/data`

2. `vi linkding/compose.yml`

3. include the superuser name and password in the `.env` file.

`vi linkding/.env`

4. `docker compose up -d`

5. once the container is running, you can remove the superuser name and password from the `.env` file.