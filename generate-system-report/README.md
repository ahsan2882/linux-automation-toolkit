# Linux System Report

A lightweight Bash utility that generates a system health report from the terminal. It provides a quick overview of CPU information, memory usage, disk capacity, system uptime, top resource-consuming processes, and failed systemd services.

## Features

- **System Information:** Hostname, operating system, kernel version, and report timestamp.
- **Uptime & Load:** System uptime, load averages, and logged-in user count.
- **CPU:** Processor count, CPU model, and optional live CPU utilization using `mpstat`.
- **Memory:** Total, used, free, and available memory, including a configurable usage warning threshold.
- **Disk Usage:** Filesystem capacity, available space, filesystem type, and configurable disk usage warnings.
- **Top Processes:** Displays the top processes by CPU and memory consumption.
- **Failed Services:** Lists failed systemd services to help identify services that require attention.
- **Readable Output:** Uses colored headings and warnings to make important information easier to identify.

## Requirements

- Linux operating system with Bash.
- Standard Linux utilities: `hostname`, `date`, `uname`, `uptime`, `awk`, `free`, `df`, `ps`, and `systemctl`.
- `mpstat` from the `sysstat` package is optional and enables live CPU utilization reporting.
- Sufficient permissions to inspect the relevant system information. Root privileges are generally not required for basic reporting.

## Installation

### 1. Create the script

Save the script as `system-report.sh`.

### 2. Make it executable

```bash
chmod +x system-report.sh
```

### 3. Install system-wide (optional)

Move the script to a directory in your system's executable path:

```bash
sudo install -m 755 system-report.sh /usr/local/bin/system-report.sh
```

You can now run it from any directory.

## Usage

Run the report:

```bash
system-report.sh
```

If the script is not installed system-wide, run it from its directory:

```bash
./system-report.sh
```

### Optional CPU monitoring support

On Ubuntu or Debian, install `sysstat` to enable CPU utilization reporting through `mpstat`:

```bash
sudo apt update
sudo apt install -y sysstat
```

## Configuration

The script provides configurable thresholds and process limits near the beginning of the file.

| Setting                    | Description                                        | Default |
| -------------------------- | -------------------------------------------------- | ------: |
| `TOP_PROCESSES`            | Number of processes shown in each resource ranking |     `5` |
| `DISK_WARNING_THRESHOLD`   | Disk usage percentage that triggers a warning      |    `80` |
| `MEMORY_WARNING_THRESHOLD` | Memory usage percentage that triggers a warning    |    `80` |

For example, to warn when disk usage reaches 90%:

```bash
DISK_WARNING_THRESHOLD=90
```

Change the corresponding value in the script before running it.

## Example Output

```text
SYSTEM REPORT
Hostname: server01
Date:     2026-10-27 18:53:00 PKT
OS:       Ubuntu 24.04 LTS
Kernel:   6.x

=== UPTIME & LOAD ===
up 12 days, 4 hours
Load averages: 0.32 0.25 0.18
Logged-in users: 1

=== MEMORY ===
               total   used   free  shared  buff/cache  available
Mem:             16Gi   4.0Gi  8.0Gi  512Mi       4.0Gi       11Gi
Swap:             2Gi      0B   2.0Gi

Memory usage: 25%

=== DISK USAGE ===
Filesystem     Type  Size  Used Avail Use% Mounted on
/dev/nvme0n1p2 ext4  100G   45G   50G  48% /

=== TOP 5 PROCESSES BY CPU ===
    PID COMMAND         %CPU %MEM
   1234 python3          8.2  2.5
   2345 nginx            4.1  1.0

=== TOP 5 PROCESSES BY MEMORY ===
    PID COMMAND         %CPU %MEM
   1234 python3          8.2  2.5
   3456 postgres         1.2  8.0

=== FAILED SYSTEMD SERVICES ===
No failed services.

Report completed.
```

_The output above is illustrative; actual values depend on the machine and its current workload._

## How It Works

1. Collects system metadata using standard Linux commands.
2. Reads load averages and uptime from system utilities and kernel information.
3. Displays memory statistics and calculates memory usage against total memory.
4. Lists mounted filesystem usage while excluding temporary filesystems and read-only SquashFS mounts.
5. Sorts running processes by CPU and memory consumption.
6. Queries systemd for failed units and displays any detected failures.
7. Prints warnings when configured memory or disk usage thresholds are reached.

## Troubleshooting

### `mpstat` is unavailable

Install `sysstat` or continue without live CPU utilization. The rest of the report can still run.

### Failed systemd services are listed

Inspect a service using:

```bash
sudo systemctl status SERVICE_NAME --no-pager -l
sudo journalctl -u SERVICE_NAME -n 50 --no-pager
```

Replace `SERVICE_NAME` with the affected service, such as `atop.service`.

A failed service should be investigated before being restarted or disabled.

### Disk usage warnings appear

Inspect filesystem capacity:

```bash
df -hT
```

Identify large directories on a particular filesystem:

```bash
sudo du -xhd1 / 2>/dev/null | sort -h
```

Review the results before deleting files.

## Limitations

- This is a point-in-time report, not continuous monitoring.
- Load averages represent system load over time and are not equivalent to CPU utilization percentages.
- Process visibility and service details can vary with user permissions and system configuration.
- The script does not automatically repair failed services or clean up disk space.
- The report does not currently provide network throughput, temperature, SMART health, or historical performance graphs.

## Possible Improvements

- Add configurable critical and warning thresholds with a nonzero exit status when critical limits are exceeded.
- Include selected application services, such as Docker, Frigate, and Tailscale.
- Add network interface and disk I/O statistics.
- Export reports to text, JSON, or CSV.
- Schedule periodic reports using a systemd service and timer.
- Send alerts by email when critical thresholds are exceeded.

## License

Use, modify, and distribute this script according to the license chosen for your project.
