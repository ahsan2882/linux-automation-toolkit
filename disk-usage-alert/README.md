# Disk Usage Alert

A lightweight Linux disk-usage monitoring utility written in Go. It checks configured filesystem mount points nightly and sends an email when usage reaches or exceeds a configurable threshold.

## Features

- Configurable disk-usage threshold.
- Multiple filesystem mount points.
- Linux filesystem statistics via `syscall.Statfs`.
- Email alerts over SMTP with TLS.
- Configuration loaded directly from a file.
- Runs manually or through systemd.
- Logs available through `journalctl`.
- No third-party Go dependencies.

## Requirements

- Linux (Ubuntu recommended).
- Go 1.24 or later for building.
- An SMTP account with authentication and TLS support.
- systemd for scheduled execution.

## Configuration

Edit `configs/disk-usage-alert.conf`:

```ini
THRESHOLD_PERCENT=80
MOUNT_POINTS=/,/recordings

SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your-email@gmail.com
SMTP_PASSWORD=your-app-password

FROM_EMAIL=your-email@gmail.com
TO_EMAIL=recipient@example.com
```

`MOUNT_POINTS` is a comma-separated list of mount points.

Keep SMTP credentials private. Do not commit real credentials to version control.

## Build

```bash
go test ./...
go build -o bin/disk-usage-alert ./cmd/disk-alert
```

## Run manually

From the project root:

```bash
./bin/disk-usage-alert --config configs/disk-usage-alert.conf
```

The process checks all configured mount points, sends an email if any meets the threshold, and exits.

The default configuration path is relative to the current working directory. Pass an explicit path when running from elsewhere.

## Install as a systemd service

Create a dedicated system account:

```bash
sudo useradd --system --no-create-home \
  --shell /usr/sbin/nologin disk-alert
```

Install the binary:

```bash
sudo install -o root -g root -m 0755 \
  bin/disk-usage-alert /usr/local/bin/disk-usage-alert
```

Install the configuration directory and file:

```bash
sudo install -d -o root -g disk-alert -m 0750 \
  /etc/disk-usage-alert

sudo install -o root -g disk-alert -m 0640 \
  configs/disk-usage-alert.conf \
  /etc/disk-usage-alert/disk-usage-alert.conf
```

Edit the installed configuration before enabling scheduled execution.

Install the systemd units:

```bash
sudo install -o root -g root -m 0644 \
  systemd/disk-usage-alert.service \
  /etc/systemd/system/disk-usage-alert.service

sudo install -o root -g root -m 0644 \
  systemd/disk-usage-alert.timer \
  /etc/systemd/system/disk-usage-alert.timer
```

Reload systemd and enable the timer:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now disk-usage-alert.timer
```

## Test the service

Run the check immediately:

```bash
sudo systemctl start disk-usage-alert.service
```

Inspect the logs:

```bash
sudo journalctl -u disk-usage-alert.service -n 50 --no-pager
```

Inspect the next scheduled execution:

```bash
systemctl list-timers disk-usage-alert.timer
```

Check the service and timer status:

```bash
systemctl status disk-usage-alert.service
systemctl status disk-usage-alert.timer
```

## Behavior

- A filesystem below the threshold produces no email.
- A filesystem at or above the threshold triggers an email.
- Multiple affected mount points are included in one email.
- If a mount point cannot be checked, the error is logged and the remaining mount points are still checked.
- If checking or email delivery fails, the service exits with an error.
- When usage remains above the threshold, an alert is sent again on subsequent nightly runs.

## Security

The service runs under a dedicated, unprivileged account. SMTP credentials are stored in a root-owned configuration file readable by that account. SMTP communication requires TLS.

## Limitations

This utility checks only the configured mount points and runs at the configured schedule. It does not continuously monitor filesystem changes, and a threshold crossing between scheduled runs will not be detected until the next check.
