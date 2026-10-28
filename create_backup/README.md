# Linux Backup & Rotation Tool

A Bash-based backup utility that archives configured directories into timestamped `.tar.gz` files, displays live progress, excludes configurable directories and file patterns, validates completed archives, and retains a configurable number of recent backups.

This README covers only `backup.conf` and `backup.sh`.

## Files

```text
.
├── backup.conf
└── backup.sh
```

## Requirements

The script is intended for Linux systems using GNU utilities.

Required commands:

- `bash`
- `tar`
- `gzip`
- `pv`
- `du`
- `findmnt`
- `realpath`
- `flock`
- `find`
- `sort`
- `tee`
- `awk`

On Ubuntu/Debian, install the required utilities with:

```bash
sudo apt update
sudo apt install tar gzip pv coreutils util-linux findutils gawk
```

## `backup.conf`

`backup.conf` holds the settings used by `backup.sh`. Edit it before running a backup.

### Source directories

```bash
SOURCE_DIRS=(
    "/home/ahsan/Documents"
    "/home/ahsan/Projects"
)
```

List the directories to include in backups. Each path must exist and be readable by the user running the script. The script stops if any configured source directory is missing.

### Destination directory

```bash
BACKUP_DIR="/media/backup"
```

Set this to an existing, mounted backup destination. Prefer a separate physical disk or remote filesystem rather than the same disk as the source data.

The script checks that the destination exists, is writable, and is not on the same filesystem as `/`. This check alone does **not** prove that the destination is a separate physical disk. For stronger protection, verify the expected disk UUID or device before running.

The destination must already exist. The script deliberately does not create a missing destination, because doing so could place backups on the internal disk when an external drive is unmounted.

### Retention

```bash
RETENTION_COUNT=7
```

The number of matching timestamped archives to keep. For example, `7` keeps the seven newest files matching the configured backup naming pattern. Old backups are considered for deletion only after a new archive has been created and validated successfully.

### Log file

```bash
LOG_FILE="/var/log/linux-backup.log"
```

The script appends timestamped status and error messages to this file and also displays them in the terminal. The user running the script must have permission to write to the log.

For example, to create the log file and grant your current user ownership:

```bash
sudo touch /var/log/linux-backup.log
sudo chown "$USER":"$(id -gn)" /var/log/linux-backup.log
```

Alternatively, configure a log path inside a directory writable by your user.

### Archive naming

```bash
BACKUP_PREFIX="backup"
```

Archives use this pattern:

```text
backup_YYYY-MM-DD_HH-MM-SS.tar.gz
```

For example:

```text
backup_2026-10-26_14-30-00.tar.gz
```

The retention logic recognises archives that match this naming format and prefix. Keep `BACKUP_PREFIX` consistent with the archives you want this script to manage.

### Compression level

```bash
COMPRESSION_LEVEL=6
```

A value from `1` to `9` controls gzip compression:

- `1`: faster compression, generally larger archives.
- `6`: balanced default.
- `9`: slower compression, generally smaller archives.

## Exclusion patterns

### Directory and path patterns

```bash
EXCLUDE_DIR_PATTERNS=(
    "node_modules"
    ".git"
    ".svn"
    "venv"
    ".venv"
    "__pycache__"
    ".cache"
    "cache"
    "dist"
    "build"
    ".angular"
    ".next"
    "coverage"
)
```

These patterns are passed to GNU `tar` as `--exclude` rules. They can exclude matching directory names at any depth in the archived trees. For example, excluding `node_modules` helps avoid backing up installed JavaScript dependencies.

Be careful with broad names such as `cache`, `build`, and `dist`: a directory with one of these names may contain data you actually need.

### File patterns

```bash
EXCLUDE_FILE_PATTERNS=(
    "*.log"
    "*.tmp"
    "*.temp"
    "*.cache"
    "*.pyc"
    "*.pyo"
    "*.swp"
    "*.bak"
    "*~"
)
```

These patterns exclude matching file names, such as temporary files, Python bytecode, editor swap files, and logs. Remove or change any pattern if those files are important to your recovery needs.

GNU `tar` wildcard matching is used; these are not regular expressions. Review the exclusions before relying on the backups.

## `backup.sh`

`backup.sh` performs the backup using the values in `backup.conf`.

### What it does

1. Loads `backup.conf` relative to the script's own location.
2. Checks configuration values and required commands.
3. Verifies that source directories exist.
4. Checks that the destination directory exists and is writable.
5. Refuses to write to the root filesystem.
6. Uses `flock` to prevent concurrent runs.
7. Estimates the total input size, applying the configured exclusion patterns.
8. Streams the selected paths through `tar`, `pv`, and `gzip`.
9. Tests the completed gzip stream and lists the archive contents to validate the archive.
10. Renames the completed temporary archive to its final timestamped filename.
11. Removes older matching archives when the retention limit is exceeded.
12. Writes progress-independent status messages and errors to the configured log.

### Progress display

`pv` displays transferred bytes, throughput, elapsed time, and an estimated time remaining. The percentage and ETA are estimates: the size calculation and archive stream can differ because of filesystem changes, metadata, and archive overhead.

The script currently shows progress through `pv`, not the exact filename being processed.

### Run the backup

Place both files in the same directory, then run:

```bash
chmod +x backup.sh
./backup.sh
```

The script must be run by a user who can read the source directories, write to the destination, and write to the log file.

### Check the output

List archives:

```bash
ls -lh /media/backup/
```

View the log:

```bash
cat /var/log/linux-backup.log
```

Test an archive's contents without extracting it:

```bash
tar -tzf /media/backup/backup_YYYY-MM-DD_HH-MM-SS.tar.gz
```

Replace the example filename with an actual archive name.

## Safety notes

- **Use a separate device:** A backup on the same physical disk may be lost if that disk fails.
- **Confirm the mount:** The script checks the root filesystem, but this is not a complete physical-device check. Verify the expected external disk is mounted before running.
- **Check exclusions:** Excluded files and directories cannot be recovered from these archives.
- **Live-changing files:** Files changing during a backup may not form a consistent snapshot. Databases and other stateful applications may need a snapshot or application-specific backup procedure.
- **Test restoration:** Periodically extract an archive into a separate test directory and verify that important files can be recovered.
- **Retention is not off-site protection:** Seven archives on one destination device do not protect against failure, theft, fire, or damage to that device.
