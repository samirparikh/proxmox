How to install Ntfy

# Create directories for ntfy data and user as root
adduser gilligan
usermod -aG docker gilligan
mkdir -p /var/cache/ntfy /etc/ntfy
chown gilligan:gilligan /var/cache/ntfy /etc/ntfy
vi /etc/ntfy/server.yml

# Create a project directory and compose file as gilligan
mkdir -p ~/ntfy && cd ~/ntfy
vi docker-compose.yml
