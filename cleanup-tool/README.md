# Cleanup Tool

A configurable Bash utility that finds files older than a per-path retention period. It defaults to dry-run mode; files are deleted only when `--execute` is explicitly supplied.

## Features

- Reads target paths and retention ages from a configuration file.
- Shows candidate files before deletion.
- Uses `find` with `-xdev` so the scan does not cross into other mounted filesystems.
- Tracks found files, successful deletions, and failures.
- Requires an explicit `--execute` flag to delete files.

## Files

```text
cleanup-tool/
├── cleanup.sh
├── cleanup.conf        # local configuration; create from example.conf
└── example.conf
```

## Requirements

Linux with Bash and GNU `find`, `realpath`, `rm`, `date`, and common core utilities.

## Configure

```bash
cp example.conf cleanup.conf
chmod 600 cleanup.conf
```

Edit `cleanup.conf` using the exact syntax in `example.conf`. Each configuration entry identifies a path and the age in days beyond which files are eligible for cleanup. Review every path carefully; cleanup targets should be narrow, deliberate directories such as selected temporary, log, or cache locations.

The script sources the configuration as Bash. Only use a configuration file you trust. Do not configure broad or critical paths such as `/`, `/home`, or a backup destination without a precise reason and careful review.

## Usage

Preview the files that would be removed:

```bash
./cleanup.sh
```

Perform deletion:

```bash
./cleanup.sh --execute
```

Use `--help` only if supported by the current script version; otherwise inspect `./cleanup.sh` for accepted arguments. The primary supported modes are default dry-run and `--execute`.

## How it works

For each configured path, the script resolves and validates the target, finds regular files older than the configured number of days without crossing filesystem boundaries, and prints the candidates. In dry-run mode it leaves files unchanged. In execute mode it attempts to delete each candidate and reports a summary.

The age test uses `find -mtime`, which measures age in 24-hour periods; it is not calendar-date retention.

## Safety

- Always run dry-run first and read the complete candidate list.
- Confirm the path is correct and any target filesystem is mounted as expected.
- Do not assume a log/cache/temp path is safe to delete without checking the applications that use it.
- The script deletes files, not a complete policy-managed cache or log rotation configuration.
- Test with a small disposable directory before applying a configuration to important paths.
- Keep backups outside any paths managed by this tool.

## Troubleshooting

- **Invalid configuration:** compare the file with `example.conf`; check delimiters, quoting, and numeric day values.
- **No files found:** confirm the path exists, the retention period is correct, and files are older than the configured threshold.
- **Deletion failed:** check ownership, permissions, immutable attributes, and whether a file is in use.
- **Unexpected scan scope:** check mount boundaries and the configured path; `-xdev` prevents traversal onto other filesystem devices but does not replace careful path selection.
