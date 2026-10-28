# System Report

A Bash script that prints a point-in-time overview of Linux system health. It is intended for quick diagnostics and manual inspection, not continuous monitoring.

## Report sections

- Hostname, local date/time, operating system, and kernel version.
- Uptime, load averages, and logged-in user count.
- Logical processor count and CPU model.
- Live CPU utilization when `mpstat` is installed.
- Memory statistics and a configurable memory-use warning.
- Filesystem usage and configurable disk-use warnings.
- Top processes ranked by CPU and memory.
- Failed systemd services.

## Requirements

- Linux with Bash.
- Common commands: `hostname`, `date`, `awk`, `uname`, `uptime`, `who`, `wc`, `nproc`, `free`, `df`, `ps`, `head`, and `systemctl`.
- `mpstat` is optional and supplied by `sysstat`.

On Ubuntu/Debian, install optional CPU reporting support with:

```bash
sudo apt update
sudo apt install -y sysstat
```

## Run

```bash
chmod +x system-report.sh
./system-report.sh
```

To install system-wide:

```bash
sudo install -m 755 system-report.sh /usr/local/bin/system-report
system-report
```

The report does not need root privileges for most basic data, though some process or service details may depend on permissions.

## Configuration

Edit the constants near the top of `system-report.sh`:

| Setting                    | Default | Meaning                                                                        |
| -------------------------- | ------: | ------------------------------------------------------------------------------ |
| `TOP_PROCESSES`            |    `15` | Number of process rows shown in each CPU/memory ranking, excluding the header. |
| `DISK_WARNING_THRESHOLD`   |    `80` | Warn when a reported filesystem usage percentage is at least this value.       |
| `MEMORY_WARNING_THRESHOLD` |    `80` | Warn when calculated memory usage reaches this percentage.                     |

These values are script constants, not a separate configuration file or command-line options. Change them in the script and save before running.

## Interpreting the report

- Linux load averages are not CPU utilization percentages; interpret them in relation to the number of CPU cores and workload.
- Memory use is calculated from `MemTotal` and `MemAvailable`, which is generally more useful than treating all cache as unavailable memory.
- The disk section excludes `tmpfs`, `devtmpfs`, and `squashfs`; other filesystems may still appear.
- `systemctl --failed` reports failed units visible to the current system manager.

## Troubleshooting

- **No live CPU percentage:** install `sysstat`; the rest of the report remains available.
- **A service is failed:** inspect it before restarting or disabling it:

  ```bash
  sudo systemctl status SERVICE_NAME --no-pager -l
  sudo journalctl -u SERVICE_NAME -n 100 --no-pager
  ```

- **Disk warning:** inspect capacity with `df -hT`, then investigate large directories before deleting anything.

## Limitations

- A snapshot only; it does not collect historical metrics or send alerts.
- It does not repair services, clear disk space, or change system settings.
- It does not currently report network throughput, disk I/O history, hardware temperatures, SMART status, or container-specific resource metrics.
