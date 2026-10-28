# Backup Restore Verifier

A Bash utility for checking the integrity of timestamped `.tar.gz` backups and testing that they can be extracted into a temporary workspace.

The verifier is intended to validate backups without restoring files to their original locations.

## Features

- Finds the latest backup matching the configured naming pattern.
- Checks gzip integrity and tar archive structure.
- Validates archive member paths before extraction.
- Extracts the archive into a uniquely named temporary directory.
- Compares the archive with the extracted files.
- Logs verification results and returns a success or failure exit code.
- Cleans up temporary files after verification, according to the configured failure-retention setting.

## Project structure

```text
backup-restore-verify/
├── verify.conf
├── verify.sh
├── lib/
│   ├── archive-validator.sh
│   ├── restore-manager.sh
│   └── checksum-verifier.sh
└── logs/
    └── verify.log
```

`verify.sh` is the entry point. The scripts in `lib/` contain archive validation, temporary extraction, and content-comparison functions.

## Requirements

The verifier is designed for Linux and expects Bash and GNU command-line utilities, including:

- `tar` (GNU tar)
- `gzip`
- `find`
- `sort`
- `head`
- `wc`
- `sha256sum` (if used by the configured verification implementation)
- `realpath`
- `mktemp`
- `flock`
- `tee`
- `diff` (if used by the configured verification implementation)

On Ubuntu, install the common dependencies with:

```bash
sudo apt update
sudo apt install tar gzip findutils coreutils util-linux diffutils
```

Check the commands used by your current scripts and install any missing utilities.

## Configuration

Edit `verify.conf` before running the verifier. Example:

```bash
#!/usr/bin/env bash

BACKUP_DIR="/media/backup"
BACKUP_PREFIX="backup"
TEMP_DIR="/tmp"
VERIFY_LOG="logs/verify.log"
KEEP_TEMP_ON_FAILURE=false
```

| Setting                | Description                                                                                                        |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `BACKUP_DIR`           | Directory containing the backup archives.                                                                          |
| `BACKUP_PREFIX`        | Prefix used in backup filenames.                                                                                   |
| `TEMP_DIR`             | Parent directory for the temporary extraction workspace. Ensure it has enough free space for the extracted backup. |
| `VERIFY_LOG`           | Log file path. Relative paths are resolved from the project directory if implemented that way in `verify.sh`.      |
| `KEEP_TEMP_ON_FAILURE` | When supported by the script, controls whether the temporary workspace is retained after a failed verification.    |

### Backup filename pattern

The archive discovery logic expects names in this general format:

```text
backup_YYYY-MM-DD_HH-MM-SS.tar.gz
```

For example:

```text
backup_2026-10-26_21-00-00.tar.gz
```

Ensure the pattern in `verify.sh` matches the naming convention used by your backup script.

## Setup

From the project directory:

```bash
chmod +x verify.sh
chmod +x lib/*.sh
```

Check the configuration and ensure the backup directory exists and is readable:

```bash
ls -ld /media/backup
ls -lh /media/backup
```

Create the log directory if it does not already exist:

```bash
mkdir -p logs
```

If your configuration uses a log path under the project directory, ensure the current user can write to it.

## Run verification

From the project directory:

```bash
./verify.sh
```

The verifier selects the latest archive that matches the configured prefix and timestamp pattern. Review the console output and log file for the result.

To inspect the log:

```bash
tail -n 100 logs/verify.log
```

Use the actual path configured by `VERIFY_LOG` if it differs from this example.

## Verification workflow

1. **Locate an archive** matching the configured filename pattern.
2. **Check gzip integrity** with `gzip -t`.
3. **Inspect tar structure and paths** before extracting.
4. **Extract into a temporary workspace** under `TEMP_DIR`.
5. **Compare the archive with the extracted files** using the configured comparison implementation.
6. **Report the result**, clean up temporary files, and exit with a status code.

The verifier does **not** restore files to their original paths. Its extraction is for testing only.

## Exit status

For use in scripts and automation, the intended exit statuses are:

- `0` — verification passed.
- Non-zero — verification failed, configuration was invalid, or a required command/archive was unavailable.

Confirm the exact behavior in `verify.sh`, especially if you modify its error handling.

## Troubleshooting

### No matching archive found

- Check `BACKUP_DIR` and `BACKUP_PREFIX`.
- Confirm that filenames follow the expected timestamp pattern.
- Verify that the backup directory is mounted and readable.

### Gzip or tar validation fails

The archive may be truncated, damaged, or not a valid gzip-compressed tar archive. Preserve the original archive and investigate before deleting or replacing it.

You can run basic checks manually:

```bash
gzip -t /media/backup/backup_2026-10-26_21-00-00.tar.gz
tar -tzf /media/backup/backup_2026-10-26_21-00-00.tar.gz >/dev/null
```

Replace the example filename with the archive you want to inspect.

### Verification takes too long

Repeatedly running `tar -xOzf` for every file can be extremely slow because the archive may be decompressed and scanned many times. Prefer a single-pass archive comparison or another design that avoids rescanning the full archive for each member.

Check the available space in the temporary directory:

```bash
df -h /tmp
```

For large archives, set `TEMP_DIR` to a filesystem with enough free space.

### Comparison reports permission or mode differences

Archive comparison may check metadata such as file modes as well as file contents. Extraction settings and the process `umask` can affect restored modes. Review the comparison output before concluding that file contents are corrupt.

### Temporary workspace is retained or removed unexpectedly

Check `KEEP_TEMP_ON_FAILURE` and the cleanup logic in `verify.sh`. Retaining failed workspaces can help debugging, but they may consume significant disk space and can contain private data.

## Safety notes

- Keep the verifier's temporary directory restricted to trusted users.
- Ensure the archive path-validation step runs before extraction.
- Do not extract untrusted archives without reviewing the validation logic.
- Verification does not replace a tested backup and disaster-recovery plan.
- A successful integrity check cannot prove that a backup contains every file you intended to back up; it only verifies the checks performed by this utility.
- Consider periodically testing a restore into an isolated environment.

## Limitations

- The verifier checks only the archive selected by its discovery logic, typically the latest matching archive.
- Results depend on the correctness of the archive path validation and comparison functions.
- If the verifier does not generate and compare a trusted checksum manifest, it should not be described as providing an independent checksum-based proof of every file's contents.
- Filenames containing unusual characters, duplicate archive member names, symbolic links, and hard links require careful handling in the validator and comparison implementation.

## License

Add the license that applies to this project before publishing or distributing it.
