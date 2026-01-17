Create new Alpine virtual machine on Proxmox:

### Quick import for cloud image
```
qm create 9000 --memory 1024 --net0 virtio,bridge=vmbr0 --name alpine-template
qm importdisk 9000 nocloud_alpine-3.23.2-x86_64-bios-cloudinit-r0.qcow2 local-lvm
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0
qm set 9000 --ide2 local-lvm:cloudinit
qm set 9000 --boot c --bootdisk scsi0
qm resize 9000 scsi0 10G
```

### Set cloud-init credentials for root
```
qm set 9000 --ciuser root
qm set 9000 --cipassword 'yourpassword'
```

#### Or use an SSH key instead (recommended)
```
qm set 9000 --ciuser root
qm set 9000 --sshkeys ~/.ssh/authorized_keys
```

#### Or from a specific public key file:
```
qm set 9000 --sshkeys /path/to/your/key.pub
```

### Configure networking (pick one)
```
# DHCP (easiest)
qm set 9000 --ipconfig0 ip=dhcp

# Or static IP
qm set 9000 --ipconfig0 ip=192.168.1.50/24,gw=192.168.1.1
```

### Start the VM
```
# Add a serial port (for qm terminal)
qm set 9000 --serial0 socket

# Enable the guest agent
qm set 9000 --agent enabled=1

# Start it
qm start 9000
```

### Connect
```
# Via SSH (if you set a key and have network)
ssh root@<vm-ip>

# Or use the Proxmox console if you set a password
qm terminal 9000
# (Ctrl+O to exit the terminal)
```

### Install Docker and `doas`, as `root`
```
apk add doas
apk add docker
apk add docker-cli-compose
rc-update add docker default
service docker start
adduser samir
addgroup samir docker
addgroup samir wheel
echo "permit persist :wheel" > /etc/doas.d/wheel.conf
mkdir -p /home/samir/.ssh
vi /home/samir/.ssh/authorized_keys
chown -R samir:samir /home/samir/.ssh
chmod 700 /home/samir/.ssh
chmod 600 /home/samir/.ssh/authorized_keys
```

### Reboot to ensure user changes take effect
```
reboot
```

### Clone the image
```
qm template 9000
qm clone 9000 100 --name my-alpine-vm --full
```

Converts VM 9000 into a template. This makes it read-only and prevents accidental modification or startup.
Creates a new VM (ID 100) by copying the template:
9000 — source template ID
100 — new VM ID
--name my-alpine-vm — name for the new VM
--full — creates a complete independent copy of the disk (vs a linked clone which shares the base disk)

### To create more VMs from the template:
```
qm clone 9000 101 --name alpine-web --full
qm clone 9000 102 --name alpine-db --full
qm clone 9000 103 --name alpine-cache --full
```

Then configure each clone's cloud-init (since they'll inherit the template's settings):
```
# Set unique IP/hostname for each
qm set 101 --ipconfig0 ip=dhcp
qm set 101 --name alpine-web

qm start 101
```
