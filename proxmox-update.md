## Steps to Update Proxmox VE

### Take Backups

1. Log in as root:
```bash
ssh -i ~/.ssh/id_rsa root@<IP_ADDRESS>
```

2. Update and upgrade the system:
```bash
pveupdate     # equivalent to apt update
pveupgrade    # checks for updates and reports if a reboot is needed
pveversion -v
reboot
```

3. Get container and virtual machine IDs:
```bash
root@pve1:~# pct list
VMID       Status     Lock         Name                
100        running                 adguard             
101        stopped                 jellyfin            
102        running                 caddy               
root@pve1:~# qm list
      VMID NAME                 STATUS     MEM(MB)    BOOTDISK(GB) PID       
       103 vaultwarden          running    2048               8.00 2789      
       104 linkding             running    1024              10.00 2938      
       105 ntfy                 running    1024              10.00 3013      
      9000 alpine-template      stopped    1024              10.00 0  
```

4. Take backups:
```bash
# For an LXC
pct snapshot <CTID> pre-update-$(date +%Y%m%d)
# For a VM
qm snapshot <VMID> pre-update-$(date +%Y%m%d)
```

*need to investigate how to snapshot Jellyfin container

### Update LinkDing

1. Log into the VM directly from local machine:
```bash
ssh -i ~/.ssh/winserv samir@<IP_ADDRESS>
```

2. Perform these commands:
```
doas apk update
doas apk upgrade
doas reboot
```

Log back in and then perform:
```
$ cd linkding
$ doas rc-service docker status
 * status: started
$ docker ps
CONTAINER ID   IMAGE                               COMMAND            CREATED        STATUS                   PORTS                                         NAMES
f62818c4b84d   sissbruecker/linkding:latest-plus   "./bootstrap.sh"   4 months ago   Up 2 minutes (healthy)   0.0.0.0:9090->9090/tcp, [::]:9090->9090/tcp   linkding
$ docker compose pull
[+] Pulling 1/1
 ✔ linkding Pulled                                                                                           0.8s 
$ docker compose up -d
[+] Running 1/1
 ✔ Container linkding  Running                                                                               0.0s 
$ doas rc-update add docker default
 * rc-update: docker already installed in runlevel `default'; skipping
```

### Update ntfy

1. Log into the VM directly from local machine:
```
ssh -i ~/.ssh/winserv samir@<IP_ADDRESS>
ntfy:~$ doas apk update
v3.23.4-250-ge8ab427a05a [https://dl-cdn.alpinelinux.org/alpine/v3.23/main]
v3.23.4-252-g2593bbd7246 [https://dl-cdn.alpinelinux.org/alpine/v3.23/community]
OK: 27588 distinct packages available
ntfy:~$ doas apk upgrade
( 1/10) Upgrading runc (1.4.0-r5 -> 1.4.0-r6)
( 2/10) Upgrading containerd (2.2.0-r7 -> 2.2.0-r8)
( 3/10) Upgrading containerd-openrc (2.2.0-r7 -> 2.2.0-r8)
( 4/10) Upgrading docker-engine (29.1.3-r4 -> 29.5.1-r0)
( 5/10) Upgrading docker-openrc (29.1.3-r4 -> 29.5.1-r0)
( 6/10) Upgrading docker-cli (29.1.3-r4 -> 29.5.1-r0)
( 7/10) Upgrading docker-cli-buildx (0.30.1-r5 -> 0.30.1-r6)
( 8/10) Upgrading docker (29.1.3-r4 -> 29.5.1-r0)
( 9/10) Upgrading docker-cli-compose (2.40.3-r5 -> 2.40.3-r6)
(10/10) Upgrading linux-virt (6.18.29-r0 -> 6.18.32-r0)
Executing busybox-1.37.0-r30.trigger
Executing kmod-34.2-r1.trigger
Executing mkinitfs-3.13.0-r0.trigger
* creating /boot/initramfs-virt for 6.18.32-0-virt
Executing syslinux-6.04_pre1-r19.trigger
* /boot is device /dev/sda
OK: 475.5 MiB in 229 packages
ntfy:~$ uname -r
6.18.5-0-virt
ntfy:~$ ls /lib/modules/
6.18.32-0-virt
ntfy:~$ doas reboot
```

Log back in again then perform:
```
ntfy:~$ cd ntfy/
ntfy:~/ntfy$ doas rc-service docker status
 * status: started
ntfy:~/ntfy$ docker ps
CONTAINER ID   IMAGE                COMMAND        CREATED        STATUS         PORTS                                 NAMES
cbe10543de36   binwiederhier/ntfy   "ntfy serve"   4 months ago   Up 2 minutes   0.0.0.0:80->80/tcp, [::]:80->80/tcp   ntfy
ntfy:~/ntfy$ docker compose pull
[+] Pulling 4/4
 ✔ ntfy Pulled                                                                                               3.6s 
   ✔ ab147fda0a54 Pull complete                                                                              2.8s 
   ✔ 6a0ac1617861 Pull complete                                                                              0.7s 
   ✔ 283c7e7649a7 Pull complete                                                                              0.9s 
ntfy:~/ntfy$ docker compose up -d
[+] Running 1/1
 ✔ Container ntfy  Started                                                                                   0.6s 
ntfy:~/ntfy$ doas rc-update add docker default
 * rc-update: docker already installed in runlevel `default'; skipping
```

### Update Jellyfin

Perform the following commands:
```
ssh root@pve1
root@pve1's password: 
Linux pve1 7.0.2-2-pve #1 SMP PREEMPT_DYNAMIC PMX 7.0.2-2 (2026-05-08T06:08Z) x86_64

The programs included with the Debian GNU/Linux system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Debian GNU/Linux comes with ABSOLUTELY NO WARRANTY, to the extent
permitted by applicable law.
Last login: Mon May 11 12:23:51 2026 from 192.168.1.195
root@pve1:~# pct list
VMID       Status     Lock         Name                
100        running                 adguard             
101        running                 jellyfin            
102        running                 caddy               
root@pve1:~# pct enter 101
root@jellyfin:~# apt update
Get:1 https://pkgs.tailscale.com/stable/ubuntu noble InRelease
...
Get:31 http://archive.ubuntu.com/ubuntu noble-security/multiverse amd64 c-n-f Metadata [396 B]
Fetched 15.9 MB in 4s (4,204 kB/s)                         
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
131 packages can be upgraded. Run 'apt list --upgradable' to see them.
root@jellyfin:~# apt upgrade
root@jellyfin:~# reboot

root@pve1:~# pct enter 101
root@jellyfin:~# systemctl status jellyfin
● jellyfin.service - Jellyfin Media Server
     Loaded: loaded (/usr/lib/systemd/system/jellyfin.service; enabled; preset: enabled)
    Drop-In: /etc/systemd/system/jellyfin.service.d
             └─jellyfin.service.conf
     Active: active (running) since Wed 2026-05-20 12:33:15 EDT; 39s ago
   Main PID: 234 (jellyfin)
      Tasks: 20 (limit: 34856)
     Memory: 254.5M (peak: 262.7M)
        CPU: 14.134s
     CGroup: /system.slice/jellyfin.service
             └─234 /usr/bin/jellyfin --webdir=/usr/share/jellyfin/web --ffmpeg=/usr/lib/jellyfin-ffmpeg/ffmpeg

May 20 12:33:15 jellyfin systemd[1]: Started jellyfin.service - Jellyfin Media Server.
May 20 12:33:15 jellyfin (jellyfin)[234]: jellyfin.service: Referenced but unset environment variable evaluates t>
May 20 12:33:20 jellyfin jellyfin[234]: [12:33:20] [WRN] The WebRootPath was not found: /var/lib/jellyfin/wwwroot>
root@jellyfin:~#
```

### Update vaultwarden

Log into `root` via `ssh root@192.168.1.161` or the Console.
Run:
```
apt update
apt upgrade
reboot
```

Log back in:
```
su samir
samir@vaultwarden:~$ cd vaultwarden/
samir@vaultwarden:~/vaultwarden$ docker compose pull
[+] pull 7/7
 ✔ Image vaultwarden/server:latest Pulled                                                                     6.6s
samir@vaultwarden:~/vaultwarden$ docker compose up -d
[+] up 1/1
 ✔ Container vaultwarden Started
```

### Update AdGuard Home

Log into the container:
```
ssh -i ~/.ssh/winserv root@<IP_ADDRESS>
cp /opt/AdGuardHome/AdGuardHome.yaml .
cp -r /opt/AdGuardHome/data .
apt update
apt upgrade
reboot
```

Log back in and then perform:
```
root@adguard:~# curl -L -S -o '/tmp/AdGuardHome_linux_amd64.tar.gz' -s 'https://static.adguard.com/adguardhome/release/AdGuardHome_linux_amd64.tar.gz'
root@adguard:~# cd /opt/AdGuardHome/
sudo ./AdGuardHome -s stop
root@adguard:/opt/AdGuardHome# tar -C /tmp/ -f /tmp/AdGuardHome_linux_amd64.tar.gz -x -v -z
root@adguard:~# cp /tmp/AdGuardHome/AdGuardHome /opt/AdGuardHome/AdGuardHome
root@adguard:~# cp AdGuardHome.yaml /opt/AdGuardHome/
root@adguard:~# cp data /opt/AdGuardHome/
root@adguard:~# cp -r data /opt/AdGuardHome/
root@adguard:~# cd /opt/AdGuardHome/
root@adguard:/opt/AdGuardHome# ./AdGuardHome -s start
2026/05/20 13:35:04.728415 [info] starting adguard home version="AdGuard Home, version v0.107.75"
2026/05/20 13:35:04.729595 [info] service: AdGuard Home, version v0.107.75
2026/05/20 13:35:04.729619 [info] service: control action=start
2026/05/20 13:35:04.730533 [info] service_manager: starting service name=AdGuardHome
```
