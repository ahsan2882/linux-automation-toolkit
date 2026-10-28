# Scheduled Backup Service

Example systemd units that run the backup script daily and then run backup verification as a post-step.

## Files

- `backup.service` — oneshot unit that runs `create-backup/backup.sh`, followed by `verify-backup/verify.sh`.
- `backup.timer` — schedules the service daily at 02:00 local system time.

## Configure before installing

These units contain absolute paths and a specific user. They are examples and must be edited for the target machine.

1. Update `ExecStart` and `ExecStartPost` in `backup.service` to the actual absolute paths of the scripts.
2. Set `User` to the account that owns or can access the source data, backup destination, log files, and configuration files.
3. Ensure the backup destination is mounted before the timer runs.
4. Ensure `create-backup/backup.conf` and `verify-backup/verify.conf` agree on the archive destination, prefix, and source directories.
5. Run both scripts manually as the configured service user before scheduling them.

Because `verify-backup` may write to a protected log path, adjust `VERIFY_LOG` to a location writable by the service user or deliberately configure suitable permissions.

## Install

From the repository root, after editing the unit files:

```bash
sudo install -m 644 timed-backup-service/backup.service /etc/systemd/system/backup.service
sudo install -m 644 timed-backup-service/backup.timer /etc/systemd/system/backup.timer
sudo systemd-analyze verify /etc/systemd/system/backup.service /etc/systemd/system/backup.timer
sudo systemctl daemon-reload
sudo systemctl enable --now backup.timer
```

Check the next run:

```bash
systemctl list-timers backup.timer
```

Run the service immediately for testing:

```bash
sudo systemctl start backup.service
sudo systemctl status backup.service --no-pager -l
sudo journalctl -u backup.service -n 100 --no-pager
```

The timer uses `OnCalendar=*-*-* 02:00:00` and `Persistent=true`; if a scheduled run is missed while the machine is off, systemd can trigger it when the timer is activated again.

## Important behavior

`ExecStartPost` runs verification after the backup command completes successfully. If backup creation fails, the post-step is not a substitute for a successful backup. Review the service journal after each run and periodically perform a manual restore into an isolated directory.

The service unit is a starting point, not a complete backup security policy. Consider filesystem mount dependencies, network-mounted destinations, least-privilege access, failure notifications, and off-site replication before relying on it for production data.
