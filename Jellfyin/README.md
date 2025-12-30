# Proxmox Media SSD Mount Guide

Complete guide for mounting an external SSD with media files on Proxmox and making it accessible to Jellyfin LXC containers.

## Overview

This guide covers:
- Installing Jellyfin LXC container using community helper scripts
- Permanently mounting an external SSD (btrfs filesystem) to the Proxmox host
- Adding the SSD as Proxmox storage for containers
- Configuring LXC container bind mounts
- Setting correct permissions for Jellyfin access
- Backing up critical Jellyfin configuration and data

## System Information

- **Disk**: `/dev/sda` (labeled "storage")
- **Filesystem**: btrfs
- **Host Mount Point**: `/mnt/storage`
- **Container Mount Point**: `/mnt/media`
- **Media Location**: `/mnt/storage/media`

---

## Installing Jellyfin LXC Container

This guide uses the Proxmox VE Helper-Scripts community project for easy Jellyfin installation.

### Using the Community Helper Script

**Script Source**: https://community-scripts.github.io/ProxmoxVE/scripts?id=jellyfin

The helper script automates the creation and configuration of a Jellyfin LXC container with optimal settings.

#### Installation Steps

1. **Run the installation script** on your Proxmox host:

```bash
bash -c "$(wget -qLO - https://github.com/community-scripts/ProxmoxVE/raw/main/ct/jellyfin.sh)"
```

2. **Follow the interactive prompts**:
   - Choose **privileged** or **unprivileged** container (this guide uses privileged)
   - Select storage location (choose `storage-ssd` if already configured, or `local` initially)
   - Set container resources (CPU cores, RAM, disk size)
   - Configure network settings

3. **Default Configuration** (can be customized):
   - Container OS: Debian or Ubuntu (latest stable)
   - Jellyfin: Latest stable version
   - Required dependencies: FFmpeg, hardware acceleration support
   - Default ports: 8096 (HTTP), 8920 (HTTPS)

4. **After installation**:
   - Container ID will be assigned (e.g., 101)
   - Jellyfin will be accessible at `http://<proxmox-ip>:8096`
   - Complete initial Jellyfin setup through web interface

### Post-Installation Steps

After the helper script completes:

1. **Configure storage** (if not done during installation):
   - Add SSD as Proxmox storage (see Part 2 below)
   - Add bind mount for media access (see Part 3 below)

2. **Set permissions** for media access (see Part 4 below)

3. **Configure backups** (see Backup Procedures section)

### Important Notes About Helper Script

- **Privileged vs Unprivileged**: This guide assumes a **privileged** container for simplicity
  - Privileged: Same UID/GID as host, easier permissions, slightly less secure
  - Unprivileged: Mapped UIDs, more secure, requires additional UID mapping configuration

- **Storage Location**: If you run the script before adding the SSD storage:
  - Container installs to default storage (usually `local-lvm`)
  - Can migrate to SSD later, or recreate on SSD storage

- **Container ID**: The script assigns the next available ID (e.g., 100, 101, 102)
  - Note this ID for all subsequent configuration steps

### Alternative: Manual Installation

If you prefer manual installation or need more control:

```bash
# Create container with specific settings
pct create 101 local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
  --hostname jellyfin \
  --storage storage-ssd \
  --rootfs storage-ssd:8 \
  --memory 2048 \
  --cores 2 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --privileged 1 \
  --features nesting=1 \
  --onboot 1

# Start container
pct start 101

# Install Jellyfin manually
pct enter 101
apt update
apt install -y curl gnupg
curl -fsSL https://repo.jellyfin.org/install-debuntu.sh | bash
```

---

## Part 1: Mounting the SSD on Proxmox Host

### Step 1: Create Permanent Mount Point

```bash
mkdir -p /mnt/storage
```

### Step 2: Get Disk UUID

```bash
blkid /dev/sda
```

This displays the UUID and filesystem type. Copy the UUID for the next step.

### Step 3: Add to /etc/fstab

Edit `/etc/fstab`:

```bash
nano /etc/fstab
```

Add one of the following lines:

```bash
# Using UUID (recommended - more reliable)
UUID=your-uuid-here  /mnt/storage  btrfs  defaults,nofail  0 2

# OR using LABEL (simpler but less robust)
LABEL=storage  /mnt/storage  btrfs  defaults,nofail  0 2
```

**Option explanations:**
- `nofail` - System will boot even if drive isn't connected
- `0 2` - Don't dump, fsck after root filesystem

### Step 4: Test the Mount

```bash
# Unmount any temporary mounts
umount /mnt/tmp

# Test the fstab entry
mount -a

# Verify it mounted correctly
ls -la /mnt/storage/media
df -h | grep storage
```

---

## Part 2: Add SSD as Proxmox Storage

This allows you to install LXC containers directly on the SSD.

### Option A: Via Web GUI

1. Navigate to: **Datacenter → Storage → Add → Directory**
2. Fill in:
   - **ID**: `storage-ssd` (or your preferred name)
   - **Directory**: `/mnt/storage`
   - **Content**: Check boxes for desired content types:
     - Container
     - Disk image
     - VZ template
     - Backup
     - Snippets
   - **Nodes**: Select your node (e.g., `pve1`)
3. Click **Add**

### Option B: Via CLI

```bash
pvesm add dir storage-ssd --path /mnt/storage \
  --content rootdir,images,vztmpl,backup,snippets
```

**Content types:**
- `rootdir` - Container root directories
- `images` - VM/container disk images
- `vztmpl` - Container templates
- `backup` - Backups
- `snippets` - Hook scripts, cloud-init configs

### Verify Storage

```bash
pvesm status
```

You should see `storage-ssd` listed.

---

## Part 3: Configure Jellyfin LXC Container

> **Note**: If you used the community helper script, your container is already created. This section covers adding the media bind mount and optionally installing the container on the SSD storage.

### Creating Container on the SSD

When creating the Jellyfin container, specify `storage-ssd` as the storage location.

**Via CLI example:**
```bash
pct create 101 local:vztmpl/your-template.tar.gz \
  --storage storage-ssd \
  --rootfs storage-ssd:8 \
  --privileged 1
```

### Add Bind Mount for Media Access

The container needs a bind mount to access the media directory.

**Method 1: Via CLI**

```bash
# Stop the container
pct stop 101

# Add the bind mount
pct set 101 -mp0 /mnt/storage/media,mp=/mnt/media

# Start the container
pct start 101
```

**Method 2: Edit Config Manually**

```bash
nano /etc/pve/lxc/101.conf
```

Add this line:
```
mp0: /mnt/storage/media,mp=/mnt/media
```

Save and restart:
```bash
pct reboot 101
```

### Verify Bind Mount

```bash
# Enter the container
pct enter 101

# Check if media is accessible
ls -la /mnt/media
ls -la /mnt/media/Shows
```

---

## Part 4: Set Correct Permissions

### Check Jellyfin User Inside Container

```bash
# Inside the container
id jellyfin
ps aux | grep jellyfin
```

Example output:
```
uid=107(jellyfin) gid=110(jellyfin) groups=110(jellyfin),44(video),993(render)
```

### Fix Permissions on Host

Since Jellyfin runs as UID 107:GID 110, and media is owned by 1000:1001, you need to adjust permissions.

**Option 1: Make Media Readable by All (Recommended for homelab)**

```bash
# On Proxmox host
chmod -R 755 /mnt/storage/media
```

This gives:
- Owner (1000): read/write/execute
- Group (1001): read/execute  
- Others (including jellyfin UID 107): read/execute

**Option 2: Change Group Ownership to Jellyfin**

```bash
# On Proxmox host
chgrp -R 110 /mnt/storage/media
chmod -R 750 /mnt/storage/media
```

**Option 3: Change Full Ownership to Jellyfin**

```bash
# On Proxmox host (if you don't need host user access)
chown -R 107:110 /mnt/storage/media
```

### Configure Jellyfin Media Library

In Jellyfin web interface:
1. Go to **Dashboard → Libraries**
2. Add Library
3. Point to `/mnt/media/Shows` (or relevant subdirectory)
4. Scan library

---

## Verification Checklist

- [ ] SSD mounts automatically at boot (`df -h | grep storage`)
- [ ] Storage shows in Proxmox (`pvesm status`)
- [ ] Container can see media directory (`pct enter 101; ls /mnt/media`)
- [ ] Jellyfin can read files (check library scan)
- [ ] Permissions allow Jellyfin access (`ls -la /mnt/storage/media`)
- [ ] Backup script configured and tested (`/usr/local/bin/backup-jellyfin.sh`)
- [ ] Automated backups scheduled (cron or Proxmox backup job)

---

## Troubleshooting

### Media Not Visible in Container

**Problem**: Jellyfin can't see directories even with correct permissions.

**Solution**: Verify bind mount exists:
```bash
# On host
pct config 101 | grep mp0

# Should show: mp0: /mnt/storage/media,mp=/mnt/media
```

### Permission Denied Errors

**Check current ownership:**
```bash
# On host
ls -la /mnt/storage/media
```

**Verify Jellyfin UID:**
```bash
# In container
pct enter 101
id jellyfin
```

### SSD Not Mounting at Boot

**Check fstab syntax:**
```bash
cat /etc/fstab | grep storage
```

**Test mount manually:**
```bash
mount -a
```

---

## Directory Structure Reference

```
/mnt/storage/                    # Host mount point
├── media/                       # Media files
│   ├── Shows/                   # TV shows
│   └── Documentation/           # Other media
├── jellyfin/                    # Old Jellyfin data (if migrated)
├── adguardhome/                 # Other services
├── images/                      # Proxmox container images
├── dump/                        # Proxmox backups
└── .snapshots/                  # btrfs snapshots
```

**Inside Container (ID: 101):**
```
/mnt/media/                      # Bind mount to host's /mnt/storage/media
├── Shows/
└── Documentation/
```

---

## Important Notes

1. **Privileged vs Unprivileged Containers**:
   - This guide assumes a **privileged** container
   - Privileged containers have the same UID/GID mapping as the host
   - More convenient but slightly less secure

2. **Btrfs Snapshots**:
   - The SSD uses btrfs with `.snapshots` directory
   - Permissions persist across snapshots
   - Consider snapshot strategy for data protection

3. **Container Storage Location**:
   - Container root filesystem: `storage-ssd` (on the SSD)
   - Media access: via bind mount (doesn't copy data)
   - Original media stays at `/mnt/storage/media` on host

4. **Backup Recommendations**:
   - See the **Backup Procedures** section below for detailed instructions
   - Critical: `/var/lib/jellyfin` and `/etc/jellyfin` inside container
   - Container config: `/etc/pve/lxc/101.conf` on host
   - Media files: Already on separate SSD with btrfs snapshots

---

## Quick Reference Commands

```bash
# Install Jellyfin using community helper script
bash -c "$(wget -qLO - https://github.com/community-scripts/ProxmoxVE/raw/main/ct/jellyfin.sh)"

# View mount status
df -h | grep storage
mount | grep storage

# View Proxmox storage
pvesm status

# View container config
pct config 101

# Enter container
pct enter 101

# Check container mounts
pct enter 101
df -h
mount

# Check permissions
ls -la /mnt/storage/media

# View Jellyfin process
pct enter 101
ps aux | grep jellyfin
id jellyfin

# Quick backup (from inside container)
pct enter 101
tar -czf /mnt/media/backups/jellyfin-backup-$(date +%Y%m%d).tar.gz \
  /var/lib/jellyfin /etc/jellyfin

# Proxmox container backup (from host)
vzdump 101 --storage storage-ssd --mode snapshot --compress zstd

# List available backups
ls -lh /mnt/media/backups/
```

---

## Backup Procedures

### Critical Jellyfin Directories to Backup

**Essential directories:**
- `/var/lib/jellyfin/data/` - **MOST CRITICAL** - Database, user configs, watch history, metadata
- `/var/lib/jellyfin/plugins/` - Installed plugins and configurations
- `/etc/jellyfin/` - System configuration files (system.xml, encoding.xml, logging.json)

**Optional (can be regenerated):**
- `/var/lib/jellyfin/metadata/` - Downloaded metadata and images (time-consuming to regenerate)

### Manual Backup Method

#### One-Time Backup to Host

```bash
# Enter the container
pct enter 101

# Create backup directory
mkdir -p /mnt/media/backups

# Backup all Jellyfin configuration and data
tar -czf /mnt/media/backups/jellyfin-backup-$(date +%Y%m%d-%H%M%S).tar.gz \
  /var/lib/jellyfin \
  /etc/jellyfin

# Verify the backup was created
ls -lh /mnt/media/backups/
```

#### Minimal Backup (Essential Data Only)

```bash
# Backup only the critical data directory
tar -czf /mnt/media/backups/jellyfin-data-$(date +%Y%m%d-%H%M%S).tar.gz \
  /var/lib/jellyfin/data \
  /etc/jellyfin
```

#### Backup to External Location

```bash
# Backup to a specific location on the host
tar -czf /mnt/media/backups/jellyfin-full-$(date +%Y%m%d).tar.gz \
  /var/lib/jellyfin \
  /etc/jellyfin

# Or backup directly to host path (from inside container)
# The /mnt/media bind mount allows access to host storage
```

### Automated Backup Script

Create a backup script inside the container:

```bash
# Enter container
pct enter 101

# Create backup script
cat > /usr/local/bin/backup-jellyfin.sh << 'EOF'
#!/bin/bash

# Configuration
BACKUP_DIR="/mnt/media/backups"
RETENTION_DAYS=30
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/jellyfin-backup-${DATE}.tar.gz"

# Create backup directory if it doesn't exist
mkdir -p "${BACKUP_DIR}"

# Create backup
echo "Starting Jellyfin backup at $(date)"
tar -czf "${BACKUP_FILE}" \
  /var/lib/jellyfin \
  /etc/jellyfin

# Verify backup was created
if [ -f "${BACKUP_FILE}" ]; then
  SIZE=$(du -h "${BACKUP_FILE}" | cut -f1)
  echo "Backup completed: ${BACKUP_FILE} (${SIZE})"
  
  # Remove old backups
  find "${BACKUP_DIR}" -name "jellyfin-backup-*.tar.gz" -mtime +${RETENTION_DAYS} -delete
  echo "Removed backups older than ${RETENTION_DAYS} days"
else
  echo "ERROR: Backup failed!"
  exit 1
fi
EOF

# Make it executable
chmod +x /usr/local/bin/backup-jellyfin.sh

# Test the script
/usr/local/bin/backup-jellyfin.sh
```

### Automated Backup with Cron

```bash
# Inside the container
# Edit crontab
crontab -e

# Add one of these lines:

# Daily backup at 3 AM
0 3 * * * /usr/local/bin/backup-jellyfin.sh >> /var/log/jellyfin-backup.log 2>&1

# Weekly backup on Sunday at 2 AM
0 2 * * 0 /usr/local/bin/backup-jellyfin.sh >> /var/log/jellyfin-backup.log 2>&1

# Twice daily (2 AM and 2 PM)
0 2,14 * * * /usr/local/bin/backup-jellyfin.sh >> /var/log/jellyfin-backup.log 2>&1
```

### Backup Using Proxmox Built-in Backup

Proxmox can backup the entire container, including all Jellyfin data.

**Via Web GUI:**
1. Navigate to container (pve → 101)
2. Click **Backup** → **Backup now**
3. Select storage location
4. Choose backup mode:
   - **Snapshot** - Fast, no downtime (recommended)
   - **Stop** - Stops container during backup
   - **Suspend** - Suspends container during backup

**Via CLI:**

```bash
# On Proxmox host
# One-time backup
vzdump 101 --storage local --mode snapshot --compress zstd

# Backup to specific location
vzdump 101 --dumpdir /mnt/storage/dump --mode snapshot --compress zstd
```

**Automated Proxmox Backups:**

1. Go to **Datacenter → Backup**
2. Click **Add**
3. Configure:
   - **Node**: pve1
   - **Storage**: storage-ssd (or local)
   - **Schedule**: Daily at 3:00 (or your preference)
   - **Selection mode**: Include selected VMs/Containers
   - **Select**: Container 101
   - **Retention**: Keep last 7 backups
   - **Mode**: Snapshot
   - **Compression**: ZSTD

### Restore Procedures

#### Restore from Manual Backup

```bash
# Enter the container
pct enter 101

# Stop Jellyfin service
systemctl stop jellyfin

# Backup current config (just in case)
mv /var/lib/jellyfin /var/lib/jellyfin.old
mv /etc/jellyfin /etc/jellyfin.old

# Extract backup
tar -xzf /mnt/media/backups/jellyfin-backup-20241230-030000.tar.gz -C /

# Fix ownership (if needed)
chown -R jellyfin:jellyfin /var/lib/jellyfin
chown -R root:root /etc/jellyfin

# Start Jellyfin
systemctl start jellyfin
systemctl status jellyfin
```

#### Restore Entire Container from Proxmox Backup

```bash
# On Proxmox host
# List available backups
vzdump list

# Restore to same container ID (overwrites existing)
pct restore 101 /path/to/backup/vzdump-lxc-101-*.tar.zst

# Or restore to new container ID
pct restore 102 /path/to/backup/vzdump-lxc-101-*.tar.zst
```

After restoring to a new container ID, remember to:
1. Add the bind mount for media: `pct set 102 -mp0 /mnt/storage/media,mp=/mnt/media`
2. Start the container: `pct start 102`

### Backup Verification

```bash
# Check backup file integrity
tar -tzf /mnt/media/backups/jellyfin-backup-20241230.tar.gz | head -20

# Check backup size and date
ls -lh /mnt/media/backups/

# List all backups with dates
find /mnt/media/backups/ -name "jellyfin-backup-*.tar.gz" -printf "%T@ %Tc %p\n" | sort -n
```

### Backup Strategy Recommendations

**Recommended Multi-Layer Approach:**

1. **Daily automated backups** of Jellyfin data (using cron script)
   - Retention: 30 days
   - Location: `/mnt/media/backups` (on the SSD)

2. **Weekly Proxmox container backups**
   - Retention: 4 weeks
   - Location: `storage-ssd` or separate backup storage
   - Includes entire container state

3. **Monthly off-site backups**
   - Copy important backups to external drive or cloud storage
   - Critical for disaster recovery

**Minimum Viable Backup:**
- Weekly cron backup of `/var/lib/jellyfin/data` and `/etc/jellyfin`
- Keeps you safe from accidental deletions or corruption
- Quick to restore

### What NOT to Backup

You don't need to backup:
- Media files (`/mnt/media`) - Already on separate storage with bind mount
- Jellyfin cache - Will regenerate automatically
- Transcoding temp files - Temporary by nature
- System packages - Reinstall via apt if needed

### Important Notes

1. **Backup Size**: Jellyfin data directory is typically 1-5 GB depending on library size and metadata
2. **Downtime**: Manual backups don't require stopping Jellyfin, but database consistency is better if stopped
3. **Testing**: Periodically test restore procedures to ensure backups are valid
4. **Documentation**: Keep this README with your backups for restoration instructions

---

## Related Documentation

- Proxmox VE Helper-Scripts: https://community-scripts.github.io/ProxmoxVE/
- Proxmox LXC Documentation: https://pve.proxmox.com/wiki/Linux_Container
- Jellyfin Documentation: https://jellyfin.org/docs/
- Btrfs Documentation: https://btrfs.readthedocs.io/
- Proxmox Backup: https://pve.proxmox.com/wiki/Backup_and_Restore
