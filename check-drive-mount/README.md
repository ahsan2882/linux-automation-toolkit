# Configured Drive Mounting Service

A Bash-based drive mounting utility for Ubuntu/Linux that checks configured drives at every boot and mounts any that are not already mounted. Drive definitions are maintained in a central configuration file, so drives can be added or removed without modifying the script.

## Features

- **Automatic mounting at boot** using a systemd service.
- **Centralized configuration** through `/etc/drive-mount.conf`.
- **UUID-based identification** to avoid depending on changing device names such as `/dev/sdb1`.
- **Mount status checking** to prevent mounting over an existing mount point.
- **Automatic mount-point creation** when the directory does not exist.
- **Error handling** that continues processing other drives if one fails.
- **Systemd journal logging** for troubleshooting and verification.

## Requirements

- Ubuntu or another Linux distribution using systemd.
- Bash.
- `util-linux` utilities, including `mount`, `mountpoint`, `findmnt`, and `lsblk`.
- Root privileges to mount drives and configure system services.
- Filesystem support for the configured drive types.

## Project Components

| Component       | Location                                              | Purpose                             |
| --------------- | ----------------------------------------------------- | ----------------------------------- |
| Configuration   | `/etc/drive-mount.conf`                               | Defines the drives to mount         |
| Mounting script | `/usr/local/sbin/mount-configured-drives.sh`          | Checks and mounts configured drives |
| Systemd service | `/etc/systemd/system/mount-configured-drives.service` | Executes the script during boot     |

## Installation

### 1. Identify the drives

List the available block devices, filesystems, and UUIDs:

```bash
lsblk -f
```

Example output:

```text
NAME   FSTYPE UUID                                 MOUNTPOINTS
sda
└─sda1 ext4   11111111-2222-3333-4444-555555555555
sdb
└─sdb1 ext4   aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee
```

Use the actual UUIDs from your system.

### 2. Create the configuration file

Create `/etc/drive-mount.conf`:

```bash
sudo nano /etc/drive-mount.conf
```

Add the drives you want to manage:

```text
# UUID|MOUNT_POINT|FILESYSTEM_TYPE

11111111-2222-3333-4444-555555555555|/mnt/drive1|ext4
aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee|/mnt/drive2|ext4
```

Each non-comment line must contain exactly three fields separated by `|`:

```text
UUID|MOUNT_POINT|FILESYSTEM_TYPE
```

Supported examples of filesystem types include `ext4`, `xfs`, and `ntfs3`, provided the relevant filesystem driver is installed and supported.

Set the configuration file permissions:

```bash
sudo chown root:root /etc/drive-mount.conf
sudo chmod 600 /etc/drive-mount.conf
```

**Important:** Do not wrap the entries in a Bash array such as `DRIVES=(...)`. The script reads the file line by line.

### 3. Install the mounting script

Create the script:

```bash
sudo nano /usr/local/sbin/mount-configured-drives.sh
```

Insert the mounting script provided with this project, then set its permissions:

```bash
sudo chown root:root /usr/local/sbin/mount-configured-drives.sh
sudo chmod 750 /usr/local/sbin/mount-configured-drives.sh
```

### 4. Configure systemd

Create the service unit:

```bash
sudo nano /etc/systemd/system/mount-configured-drives.service
```

Add:

```ini
[Unit]
Description=Mount configured drives at boot
After=local-fs.target
Wants=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/mount-configured-drives.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

Reload systemd and enable the service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable mount-configured-drives.service
```

The service will now run automatically during subsequent boots.

## Usage

### Run manually

Execute the script directly to check and mount the configured drives:

```bash
sudo /usr/local/sbin/mount-configured-drives.sh
```

### Run through systemd

Start the service manually:

```bash
sudo systemctl start mount-configured-drives.service
```

Check its status:

```bash
sudo systemctl status mount-configured-drives.service
```

### Verify mounted drives

Check individual mount points:

```bash
findmnt /mnt/drive1
findmnt /mnt/drive2
```

Alternatively, list all mounted filesystems:

```bash
lsblk -f
```

### View logs

View logs from the current boot:

```bash
sudo journalctl -u mount-configured-drives.service -b --no-pager
```

Follow logs interactively:

```bash
sudo journalctl -u mount-configured-drives.service -f
```

View logs from the previous boot:

```bash
sudo journalctl -u mount-configured-drives.service -b -1 --no-pager
```

## How It Works

For each entry in the configuration file, the script:

1. Reads the UUID, mount point, and filesystem type.
2. Validates that the configuration entry contains the required fields.
3. Checks whether the mount point is already mounted.
4. Skips the drive if it is already mounted.
5. Verifies that the configured UUID is available.
6. Creates the mount-point directory if necessary.
7. Mounts the filesystem using its UUID.
8. Logs the result and continues to the next drive.

If any drive fails, the script continues processing the remaining entries and exits with a nonzero status to indicate that one or more operations failed.

## Adding or Removing Drives

No changes to the script or systemd service are required.

To add a drive, append a new line to `/etc/drive-mount.conf`:

```text
bbbbbbbb-cccc-dddd-eeee-ffffffffffff|/mnt/archive|ext4
```

To remove a drive from management, remove its corresponding line from the configuration file.

Changes take effect the next time the script runs. Removing an entry does not automatically unmount the drive.

## Troubleshooting

### Invalid configuration line

Example:

```text
ERROR: Invalid configuration line for UUID ')'
```

**Cause:** The configuration file contains lines that do not follow the expected format, such as a closing parenthesis from a Bash array.

**Solution:** Use plain pipe-separated entries:

```text
UUID|MOUNT_POINT|FILESYSTEM_TYPE
```

Inspect the file:

```bash
sudo cat -n /etc/drive-mount.conf
```

### Drive UUID is unavailable

Example:

```text
ERROR: Drive UUID ... is unavailable
```

**Possible causes:**

- The drive is disconnected.
- The UUID is incorrect.
- The device is not ready or has not been detected.

Check the available UUIDs:

```bash
lsblk -f
sudo blkid
```

### Mount operation fails

Inspect the service logs:

```bash
sudo journalctl -u mount-configured-drives.service -b --no-pager
```

Try mounting manually:

```bash
sudo mount -t ext4 UUID=YOUR_UUID /mnt/drive1
```

Replace the filesystem type, UUID, and mount point with the actual values. The manual command is intended for troubleshooting when the target is not already mounted.

### Service changes are not applied

After modifying the systemd unit file, run:

```bash
sudo systemctl daemon-reload
```

After changing the configuration file, simply run the script or restart the service.

**Note:** Because the service uses `RemainAfterExit=yes`, systemd may report it as active after its initial execution even if the configuration file has since changed. To rerun it immediately:

```bash
sudo systemctl restart mount-configured-drives.service
```

## Important Considerations

- **Avoid duplicate mount management:** Do not configure the same drives independently in `/etc/fstab` unless you have deliberately designed the interaction.
- **Use correct UUIDs:** UUIDs should identify the intended partitions, not their parent disks.
- **Avoid mounting over non-empty directories:** An existing directory containing files may become hidden while the drive is mounted.
- **Handle unavailable drives:** A failed mount causes the service to report an error, but it does not prevent the remaining drives from being processed.
- **Understand the boot dependency:** This service is designed for locally attached drives that are available during boot. Network filesystems may require additional systemd dependencies.
- **Consider service ordering:** If another service needs these drives, configure that service to depend on `mount-configured-drives.service` so it does not start before the mounts are attempted.

## License

No license has been specified. Add a license file before distributing this project publicly.
