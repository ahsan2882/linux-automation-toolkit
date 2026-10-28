# Linux Cleanup Tool

A configurable Bash utility for identifying and removing old temporary files, logs, and package cache files on Linux systems. Supports configurable retention periods, dry-run previews, and explicit execution mode to help prevent accidental deletion.

## Features

- **Dry-run by default:** Preview files eligible for deletion without modifying anything.
- **Configurable retention periods:** Set a different age threshold for each directory.
- **Multiple cleanup paths:** Manage temporary directories, log directories, and package cache locations from a single configuration file.
- **Safe filename handling:** Supports filenames containing spaces and other special characters.
- **Regular files only:** Does not delete directories or follow symbolic links.
- **Custom configuration:** Specify an alternative configuration file through a command-line argument.
- **Execution summary:** Reports the number of files found, deleted, and failed.

## Requirements

- Linux operating system
- Bash
- GNU `find`
- Standard command-line utilities, including `rm`

## Project Structure

```text
cleanup-tool/
├── cleanup.sh
├── cleanup.conf
└── README.md
```

## Configuration

Edit `cleanup.conf` to define the directories to scan and their retention periods.

### Configuration format

```text
DAYS|PATH
```

- `DAYS`: Minimum file age threshold in days.
- `PATH`: Absolute path to the directory to scan.
- Lines beginning with `#` are treated as comments.
- Empty lines are ignored.

### Example

```bash
# Format: DAYS|PATH

7|/tmp
14|/var/tmp
30|/var/log
30|/var/cache/apt/archives
```

This configuration makes files older than the specified thresholds eligible for deletion.

**Important:** Review all configured paths before executing the script. Cleaning system log directories or package caches can remove useful diagnostic data or interfere with applications. Prefer package-manager-specific cleanup commands for package caches when appropriate.

## Installation

Clone or copy the project to your preferred directory.

Make the script executable:

```bash
chmod +x cleanup.sh
```

Review and customize `cleanup.conf` before running the utility.

## Usage

### Display help

```bash
./cleanup.sh --help
```

### Preview eligible files

```bash
./cleanup.sh --dry-run
```

Dry-run is the default mode, so this command is equivalent to running the script without arguments:

```bash
./cleanup.sh
```

Example output:

```text
Mode: DRY RUN — no files will be deleted.
Configuration: /path/to/cleanup.conf

Scanning: /tmp (older than 7 days)
WOULD DELETE: /tmp/old-file.tmp

-------------------- Summary --------------------
Files found:   1
Files deleted: 0 (dry-run mode)
Failures:      0
```

The output lists matching files without deleting them.

### Execute cleanup

After reviewing the dry-run results, execute the cleanup:

```bash
sudo ./cleanup.sh --execute
```

The script attempts to remove each eligible file and reports the result.

Use `sudo` only when the configured directories require elevated privileges. Files deleted with elevated privileges may not be recoverable.

### Use a custom configuration file

```bash
./cleanup.sh --dry-run --config /etc/cleanup/cleanup.conf
```

Execute using the same configuration:

```bash
sudo ./cleanup.sh --execute --config /etc/cleanup/cleanup.conf
```

## How It Works

For each valid configuration entry, the script:

1. Reads the retention period and directory path.
2. Validates the configuration entry.
3. Checks whether the target directory exists.
4. Uses `find` to identify regular files older than the configured threshold.
5. Prints matching paths in dry-run mode or removes them in execution mode.
6. Reports a summary after processing the configuration.

### File selection

The script uses the following command internally:

```bash
find "$path" -type f -mtime "+$days" -print0
```

- `-type f`: Matches regular files only.
- `-mtime "+$days"`: Matches files older than the specified age according to `find`'s modification-time rounding.
- `-print0`: Separates filenames with null characters to safely handle spaces and newlines.
- Symbolic links are not followed by default.

The search is recursive, so eligible files in subdirectories are also considered.

## Command-Line Options

| Option          | Description                                   |
| --------------- | --------------------------------------------- |
| `--dry-run`     | Preview eligible files without deleting them. |
| `--execute`     | Delete eligible files.                        |
| `--config FILE` | Use an alternative configuration file.        |
| `--help`, `-h`  | Display usage information.                    |

If both `--dry-run` and `--execute` are provided, the last option takes precedence.

## Safety Considerations

- Always run a dry-run before executing cleanup.
- Use absolute paths in the configuration.
- Avoid broad or sensitive paths such as `/`, `/home`, or application data directories unless their contents have been carefully reviewed.
- Review log retention requirements before including `/var/log`.
- Do not assume that every file under a package cache directory is safe to remove manually.
- Keep important logs and backups outside directories targeted for cleanup.
- The script does not delete directories, but it can delete files inside nested directories.
- The script does not currently enforce a path allowlist or protect against changes to files between scanning and deletion.

## Possible Enhancements

- Add an allowlist of permitted cleanup directories.
- Support exclusion patterns for specific files and subdirectories.
- Add a configurable maximum number of files to delete per run.
- Report reclaimed disk space.
- Integrate with systemd services and timers for scheduled cleanup.
- Add logging to a dedicated log file or the systemd journal.
- Add a confirmation prompt before destructive execution.
- Use package-manager-specific cleanup commands where appropriate.

## License

Specify a license before distributing or publishing this project. If no license is provided, standard copyright restrictions apply by default.
