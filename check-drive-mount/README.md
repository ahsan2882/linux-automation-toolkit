# Check and Mount Configured Drives

A Bash utility for mounting configured filesystems by UUID when they are not already mounted. It is intended for boot-time use where a list of data or backup drives must be available before dependent jobs run.

## Files

```text
check-drive-mount/
├── mount-configured-drives.sh
├── drive-mount.conf      # local configuration; create from example.conf
└── example.conf
```

## Requirements

- Linux with `mount`, `findmnt`, and `blkid`/UUID support.
- `sudo` or root privileges to mount filesystems.
- A valid filesystem UUID and an existing mount-point directory for each configured drive.

## Configure

```bash
cp example.conf drive-mount.conf
sudo chmod 600 drive-mount.conf
```

Open `drive-mount.conf` and follow the exact format and variable names in `example.conf`. Each configured drive should identify a filesystem by UUID and its intended mount point. Use the UUID reported by:

```bash
lsblk -f
sudo blkid
```

Create mount-point directories if needed, for example:

```bash
sudo mkdir -p /mnt/drive1 /mnt/drive2
```

Do not guess UUIDs. Confirm the filesystem and mount point before enabling this script at boot.

## Run manually

```bash
sudo ./mount-configured-drives.sh
```

Review the output and confirm the expected devices are mounted:

```bash
findmnt
lsblk -f
```

## Boot-time automation

For a boot-time systemd unit, use an absolute path to this script and run it as root. The unit should wait until local filesystems and the required device discovery are ready. After changing a unit:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now <your-mount-service>.service
sudo systemctl status <your-mount-service>.service --no-pager -l
sudo journalctl -u <your-mount-service>.service -n 100 --no-pager
```

Replace the placeholder with the actual unit name you create. Do not enable a boot-time mount job until manual execution has been tested.

## Important notes

- Mounting a drive over a non-empty directory hides the files already present underneath that mount point until it is unmounted.
- UUID-based configuration is more stable than relying on device names such as `/dev/sdb1`, which can change.
- This tool is not a substitute for correct `/etc/fstab` configuration where native system mount management is preferable.
- Confirm that dependent backup jobs run only after their destination filesystem is mounted. A directory existing does not prove the intended disk is mounted there.
- A missing device or invalid UUID should be investigated rather than bypassed.

## Troubleshooting

- **UUID not found:** run `lsblk -f` and `sudo blkid`, then update the configuration.
- **Mount point missing:** create the directory and check its ownership and permissions.
- **Already mounted:** use `findmnt <mount-point>` to identify what is mounted there before taking action.
- **Permission denied:** run with sudo and inspect kernel/system logs for filesystem errors.
