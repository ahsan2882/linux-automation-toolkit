# Disk Usage Alert

A Go application that checks configured filesystem mount points and sends an email through an SMTP server when usage reaches or exceeds a configured percentage threshold. It can run manually or through the supplied systemd service and timer.

## Features

- Reads a simple `KEY=VALUE` configuration file.
- Measures filesystem usage for each configured mount point.
- Logs each measurement and reports any configured mount point that reaches the threshold.
- Sends one email containing all mount points that triggered an alert during the run.
- Uses TLS: implicit TLS on port `465`, or STARTTLS on other ports.
- Returns a non-zero status when configuration, filesystem checks, or email delivery fail.

## Project layout

```text
disk-usage-alert/
├── cmd/disk-alert/main.go
├── internal/
│   ├── alert/           # SMTP email sender
│   ├── config/          # configuration parsing and validation
│   ├── filesystem/      # filesystem usage reader
│   └── monitor/         # threshold checks and notification flow
├── config/
│   ├── example.conf
│   └── disk-alert.conf  # local configuration; do not commit secrets
├── systemd/
│   ├── disk-usage-alert.service
│   └── disk-usage-alert.timer
├── go.mod
└── go.sum
```

## Requirements

- Linux.
- Go 1.24 or newer to compile.
- Network access to the configured SMTP server when sending alerts.
- An SMTP account that permits authenticated mail submission.

## Configure

Create a local configuration file:

```bash
cp config/example.conf config/disk-alert.conf
chmod 600 config/disk-alert.conf
```

Edit all values. The parser expects one `KEY=VALUE` setting per line, ignores blank lines and lines beginning with `#`, and rejects duplicate or unknown keys. Values should not include shell-style quotes; they are parsed as literal text.

| Setting             | Description                                                                                                                  |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `THRESHOLD_PERCENT` | Numeric percentage greater than `0` and at most `100`. Alert is triggered when usage is greater than or equal to this value. |
| `MOUNT_POINTS`      | Comma-separated absolute mount-point paths, e.g. `/,/mnt/archive`.                                                           |
| `SMTP_HOST`         | SMTP server hostname.                                                                                                        |
| `SMTP_PORT`         | SMTP port from `1` through `65535`; `465` uses implicit TLS, other ports require STARTTLS.                                   |
| `SMTP_USERNAME`     | SMTP authentication username.                                                                                                |
| `SMTP_PASSWORD`     | SMTP password or provider-issued app password.                                                                               |
| `EMAIL_FROM`        | Sender email address.                                                                                                        |
| `EMAIL_TO`          | Recipient email address.                                                                                                     |

Example values are in `config/example.conf`. Never commit `config/disk-alert.conf` if it contains credentials. Use a provider-issued app password where required and rotate any credential that has been exposed.

## Build and run

From this directory:

```bash
go test ./...
go build -o disk-usage-alert ./cmd/disk-alert
./disk-usage-alert --config config/disk-alert.conf
```

The program accepts `--config PATH`. The source's default path is `config/disk-usage-alert.conf`, which differs from the checked-in example/local filename; explicitly passing `--config config/disk-alert.conf` avoids ambiguity.

The application writes status and errors to standard logging. If no filesystem exceeds the threshold, no alert email is sent.

## Install the systemd schedule

The supplied units are examples and contain machine-specific absolute paths and a dedicated `disk-alert` user. Build the binary and update `systemd/disk-usage-alert.service` to use the actual absolute paths to the binary and configuration file. Ensure the configured user can read the configuration and execute the binary. The service uses filesystem and kernel hardening settings; validate that they work in your environment.

If the `disk-alert` user does not exist, create a dedicated service account according to your system's policy and grant only the access required. Do not run the service as root by default.

```bash
sudo install -m 644 systemd/disk-usage-alert.service /etc/systemd/system/
sudo install -m 644 systemd/disk-usage-alert.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now disk-usage-alert.timer
systemctl list-timers disk-usage-alert.timer
```

Check a run and its logs:

```bash
sudo systemctl start disk-usage-alert.service
sudo systemctl status disk-usage-alert.service --no-pager -l
sudo journalctl -u disk-usage-alert.service -n 100 --no-pager
```

The timer is configured for daily execution around 02:00, with `Persistent=true` and a randomized delay of up to five minutes.

## Troubleshooting

- **Config parse error:** check for duplicate keys, unknown keys, empty values, or quote characters copied from a shell configuration.
- **Mount point error:** confirm the path exists and is accessible to the service user.
- **SMTP connection/authentication failure:** check DNS, outbound network access, port settings, provider requirements, username, and app password.
- **STARTTLS error:** non-465 ports require the SMTP server to advertise STARTTLS.
- **No email:** the program sends mail only when at least one configured mount point meets the threshold.
- **Service cannot read config:** inspect file permissions and the `ExecStart` path in the unit.

## Limitations and security

- This is a periodic check, not continuous monitoring; alerts can occur only when the program runs.
- The app sends one email per run when one or more mount points trigger. It does not implement recovery notifications, alert deduplication, or escalation.
- SMTP credentials are read from a local configuration file. Protect it with restrictive permissions and never place secrets in source control.
- Filesystem usage is measured from the configured path. Ensure the path is the intended mount point, not merely a directory on the root filesystem.
