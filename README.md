# Linux Automation Toolkit

A collection of small, configurable tools for automating routine Linux administration: backups, backup verification, disk monitoring, drive mounting, cleanup, and system health reporting. Most tools are Bash scripts; the disk alert is a dependency-free Go program. Scheduling is handled by systemd services and timers.

## Tools

| Tool                                                | Language | Purpose                                                                                                                                   |
| --------------------------------------------------- | -------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| [`create_backup`](create_backup/)                   | Bash     | Creates timestamped `.tar.gz` backups with progress display, exclusion patterns, archive validation, and rotation. Includes `restore.sh`. |
| [`verify_backup`](verify_backup/)                   | Bash     | Checks the latest backup's integrity and test-extracts it into a temporary workspace without touching the original locations.             |
| [`disk-usage-alert`](disk-usage-alert/)             | Go       | Checks mount points against a usage threshold and sends an SMTP email alert when it is reached.                                           |
| [`check-drive-mount`](check-drive-mount/)           | Bash     | Mounts configured drives (by UUID) at boot if they are not already mounted.                                                               |
| [`cleanup-tool`](cleanup-tool/)                     | Bash     | Removes old files from temp, log, and package-cache directories with per-path retention. Dry-run by default.                              |
| [`generate-system-report`](generate-system-report/) | Bash     | Prints a colored system health report: CPU, memory, disk, uptime, top processes, failed services.                                         |
| [`timer_service`](timer_service/)                   | systemd  | Example `backup.service` and `backup.timer` that run the backup nightly at 02:00.                                                         |

Each tool has its own README with full installation and configuration details.

## Repository layout

```text
.
├── create_backup/          # backup.sh, restore.sh, example.conf
├── verify_backup/          # verify.sh, lib/ (validator, restore manager, checksum verifier)
├── disk-usage-alert/       # Go source, config/, systemd/ units
├── check-drive-mount/      # mount-configured-drives.sh, example.conf
├── cleanup-tool/           # cleanup.sh, example.conf
├── generate-system-report/ # system-report.sh
└── timer_service/          # backup.service, backup.timer
```

## Requirements

- Linux with systemd (Ubuntu/Debian recommended)
- Bash and GNU coreutils, `tar`, `gzip`, `find`
- `pv`, `flock`, `findmnt`, `gawk` for the backup tools
- Go 1.24+ to build `disk-usage-alert`
- Optional: `sysstat` (`mpstat`) for live CPU usage in the system report
- Root privileges for the tools that mount drives or install system services

## Getting started

```bash
git clone <your-repo-url> linux-automation-toolkit
cd linux-automation-toolkit
```

### 1. Configure

Real `.conf` files are git-ignored (only `example.conf` is tracked) because they may hold credentials and machine-specific paths. For each tool, copy the example and edit it:

```bash
cp create_backup/example.conf          create_backup/backup.conf
cp verify_backup/example.conf          verify_backup/verify.conf
cp cleanup-tool/example.conf           cleanup-tool/cleanup.conf
cp check-drive-mount/example.conf      check-drive-mount/drive-mount.conf
cp disk-usage-alert/config/example.conf disk-usage-alert/config/disk-alert.conf
```

Keep the filename each tool's README expects, and restrict permissions on any file containing secrets:

```bash
chmod 600 disk-usage-alert/config/disk-alert.conf
```

### 2. Run a tool

```bash
# Backup, then verify it
./create_backup/backup.sh
./verify_backup/verify.sh

# Restore an archive to a directory
./create_backup/restore.sh /path/to/backup_YYYY-MM-DD_HH-MM-SS.tar.gz /path/to/destination

# Preview cleanup (default), then actually delete
./cleanup-tool/cleanup.sh
./cleanup-tool/cleanup.sh --execute

# System health report
./generate-system-report/system-report.sh

# Disk alert
cd disk-usage-alert && go build -o disk-usage-alert ./cmd/disk-alert
./disk-usage-alert --config config/disk-alert.conf
```

### 3. Schedule with systemd

`timer_service/` contains a ready-made nightly backup unit pair. Edit `ExecStart=` and `User=` in `backup.service` to match your paths, then install:

```bash
sudo cp timer_service/backup.service timer_service/backup.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now backup.timer
systemctl list-timers backup.timer
```

The timer runs daily at 02:00 and uses `Persistent=true`, so a missed run (machine off) fires at next boot.

The `disk-usage-alert/systemd/` and `check-drive-mount` directories follow the same pattern with their own service and timer files; see their READMEs.

## Recommended workflow

1. `check-drive-mount` mounts backup and data drives at boot.
2. `create_backup` runs nightly through `backup.timer`.
3. `verify_backup` confirms the newest archive is intact and extractable.
4. `disk-usage-alert` warns by email before volumes fill up.
5. `cleanup-tool` reclaims space from old temp files, logs, and package caches.
6. `generate-system-report` gives a quick health snapshot on demand.

## Safety notes

- `cleanup-tool` only previews unless you pass `--execute`. Review the dry-run output and your retention paths first.
- Keep backups on a separate physical disk from the source data.
- Test restores regularly. A backup that has never been verified is an assumption.
- Never commit real configuration files or SMTP app passwords.

## License

MIT License

Copyright (c) 2026 Ahsan Shahid
