package monitor

import (
	"errors"
	"fmt"
	"log"
	"strings"

	"disk-usage-alert/internal/filesystem"
)

type UsageReader interface {
	GetUsage(mountPoint string) (filesystem.Usage, error)
}

type Notifier interface {
	Send(subject, body string) error
}

type Monitor struct {
	threshold   float64
	mountPoints []string
	reader      UsageReader
	notifier    Notifier
}

func New(
	threshold float64,
	mountPoints []string,
	reader UsageReader,
	notifier Notifier,
) *Monitor {
	return &Monitor{
		threshold:   threshold,
		mountPoints: mountPoints,
		reader:      reader,
		notifier:    notifier,
	}
}

func (m *Monitor) Run() error {
	var alerts []filesystem.Usage
	var failures []error

	for _, mountPoint := range m.mountPoints {
		usage, err := m.reader.GetUsage(mountPoint)
		if err != nil {
			failures = append(failures, err)
			log.Printf("ERROR: %v", err)
			continue
		}

		log.Printf(
			"Mount point: %s | Used: %.2f%% | Threshold: %.2f%%",
			mountPoint,
			usage.UsedPercent,
			m.threshold,
		)

		if usage.UsedPercent >= m.threshold {
			alerts = append(alerts, usage)
		}
	}

	if len(alerts) > 0 {
		var body strings.Builder

		fmt.Fprintf(
			&body,
			"Disk usage alert: threshold %.2f%% reached.\n\n",
			m.threshold,
		)

		for _, usage := range alerts {
			fmt.Fprintf(
				&body,
				"Mount point: %s\nUsed: %.2f%%\nUsed storage: %s\n"+
					"Available storage: %s\n\n",
				usage.MountPoint,
				usage.UsedPercent,
				formatBytes(usage.UsedBytes),
				formatBytes(usage.AvailableBytes),
			)
		}

		if err := m.notifier.Send(
			"Disk Usage Alert",
			body.String(),
		); err != nil {
			failures = append(
				failures,
				fmt.Errorf("send disk usage email: %w", err),
			)
		} else {
			log.Printf("Disk usage alert email sent")
		}
	} else {
		log.Printf("No filesystem exceeded the configured threshold")
	}

	return errors.Join(failures...)
}

func formatBytes(bytes uint64) string {
	const unit = 1024

	if bytes < unit {
		return fmt.Sprintf("%d B", bytes)
	}

	value := float64(bytes)
	units := []string{"KB", "MB", "GB", "TB", "PB"}

	for _, suffix := range units {
		value /= unit
		if value < unit || suffix == "PB" {
			return fmt.Sprintf("%.2f %s", value, suffix)
		}
	}

	return fmt.Sprintf("%d B", bytes)
}
