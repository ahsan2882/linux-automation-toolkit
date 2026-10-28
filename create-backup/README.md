# Create and Restore Backups

Bash utilities for creating timestamped gzip-compressed tar archives and restoring an archive into a chosen directory.

## Features

- Creates timestamped archives named `PREFIX_YYYY-MM-DD_HH-MM-SS.tar.gz`.
- Shows approximate progress, throughput, elapsed time, and ETA with `pv`.
- Supports configured source directories and tar exclusion patterns.
- Writes a SHA-256 sidecar (`.tar.gz.sha256`) and a tar member list (`.tar.gz.list`).
- Checks gzip and tar readability before publishing a completed archive.
- Uses a lock file to prevent overlapping backup runs.
- Applies retention to matching timestamped archives and their sidecar files.
- Refuses to proceed if the backup destination is missing, unwritable, or on the same filesystem device as `/`.
- Includes an interactive restore command with a validation-only dry run.

## Files

```text
create-backup/
├── backup.sh
├── backup.conf          # local configuration; create from example.conf
├── example.conf
└── restore.sh
```

Shared archive validation is implemented in `../lib/archive-validator.sh`.

## Requirements

On Ubuntu/Debian:

```bash
sudo apt update
sudo apt install -y bash tar gzip pv coreutils findutils util-linux
```

`backup.sh` also uses `du`, `findmnt`, `realpath`, `flock`, `find`, `sort`, `tee`, and `awk`.

## Configure

Create the expected configuration file:

```bash
cp example.conf backup.conf
chmod 600 backup.conf
```

Edit `backup.conf`. The script expects these settings:

| Setting                 | Purpose                                                                                                       |
| ----------------------- | ------------------------------------------------------------------------------------------------------------- |
| `BACKUP_DIR`            | Existing, writable directory where archives are stored. It must be on a different filesystem device from `/`. |
| `LOG_FILE`              | Writable log-file path.                                                                                       |
| `BACKUP_PREFIX`         | Prefix for timestamped archive names.                                                                         |
| `RETENTION_COUNT`       | Positive integer: number of newest matching archives to keep.                                                 |
| `COMPRESSION_LEVEL`     | Integer from `1` to `9`; higher levels generally trade speed for smaller archives.                            |
| `SOURCE_DIRS`           | Bash array of source directories to archive.                                                                  |
| `EXCLUDE_DIR_PATTERNS`  | Bash array of directory/file-name patterns passed to GNU tar as exclusions.                                   |
| `EXCLUDE_FILE_PATTERNS` | Bash array of file-name patterns passed to GNU tar as exclusions.                                             |

The example configuration is the definitive template for array syntax. Paths containing spaces should be quoted as array elements. Because the script sources this file as Bash, only use a configuration file you trust.

Ensure every source directory exists and the backup destination is mounted and writable before running. The script requires the destination directory to exist; it deliberately does not create it automatically.

## Create a backup

From the repository root or any directory:

```bash
./create-backup/backup.sh
```

Or from this directory:

```bash
./backup.sh
```

The script logs to the configured `LOG_FILE` and the terminal. Progress is approximate because tar adds headers and metadata beyond the estimated source size.

A successful run produces three files, for example:

```text
backup_2026-10-28_02-00-00.tar.gz
backup_2026-10-28_02-00-00.tar.gz.sha256
backup_2026-10-28_02-00-00.tar.gz.list
```

The checksum records the archive hash created during the run. The list records tar members as they are written. Keep the archive and both sidecars together: `verify-backup` requires them.

## Restore an archive

First validate and list the archive without extracting:

```bash
./restore.sh --dry-run /path/to/backup_YYYY-MM-DD_HH-MM-SS.tar.gz
```

Restore into a destination directory:

```bash
./restore.sh /path/to/backup_YYYY-MM-DD_HH-MM-SS.tar.gz /path/to/restore
```

The script validates gzip/tar readability and rejects absolute member paths and parent-directory traversal before prompting for confirmation. It creates the destination if needed and extracts without restoring original ownership or privileged permissions.

**Important:** extraction can overwrite files with matching names in the destination. Prefer a new, empty directory and inspect the dry-run listing before restoring. The restore utility validates the archive structure but does not verify the `.sha256` sidecar or `.list` sidecar.

## Retention and deletion

After creating and validating a new archive, the script sorts matching timestamped archives newest-first and removes archives beyond `RETENTION_COUNT`, along with their `.sha256` and `.list` files. Configure retention conservatively and keep another copy elsewhere before relying on automatic rotation.

## Troubleshooting

- **Destination missing:** confirm the external/backup drive is mounted and that `BACKUP_DIR` exists.
- **Destination on root filesystem:** check `findmnt -T /path/to/backup`; the script compares the destination device with the root filesystem device. This does not prove the destination is the intended physical drive.
- **Permission denied:** confirm the run user can read every source and write the destination and log.
- **`pv` not found:** install `pv` using the requirements command above.
- **Archive creation fails:** review the log and preserve existing backups. The script removes incomplete temporary artifacts on exit.
- **Verification fails:** keep the archive and sidecars intact and run `../verify-backup/verify.sh` after checking its configuration.

## Limitations

- This is a directory backup, not a full-system image; it does not by itself preserve all filesystem metadata, ACLs, extended attributes, or system state.
- The root-filesystem guard compares device IDs, not a configured UUID or physical-device identity.
- Source files can change while the archive is being created.
- A local archive does not protect against theft, fire, ransomware, or physical disk failure if the source and backup share the same location.

## Related tools

- [`../verify-backup/README.md`](../verify-backup/README.md)
- [`../timed-backup-service/`](../timed-backup-service/)
