package config

import (
	"bufio"
	"fmt"
	"os"
	"strconv"
	"strings"
)

type Config struct {
	ThresholdPercent float64
	MountPoints      []string

	SMTPHost     string
	SMTPPort     string
	SMTPUsername string
	SMTPPassword string

	EmailFrom string
	EmailTo   string
}

func Load(path string) (Config, error) {
	file, err := os.Open(path)
	if err != nil {
		return Config{}, fmt.Errorf("open config: %w", err)
	}
	defer file.Close()

	values := make(map[string]string)
	scanner := bufio.NewScanner(file)
	lineNumber := 0

	for scanner.Scan() {
		lineNumber++
		line := strings.TrimSpace(scanner.Text())

		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}

		key, value, found := strings.Cut(line, "=")
		if !found {
			return Config{}, fmt.Errorf(
				"invalid config at line %d: expected KEY=VALUE",
				lineNumber,
			)
		}

		key = strings.TrimSpace(key)
		value = strings.TrimSpace(value)

		if key == "" || value == "" {
			return Config{}, fmt.Errorf(
				"invalid config at line %d: empty key or value",
				lineNumber,
			)
		}

		if _, exists := values[key]; exists {
			return Config{}, fmt.Errorf(
				"duplicate config key %q at line %d",
				key, lineNumber,
			)
		}

		values[key] = value
	}

	if err := scanner.Err(); err != nil {
		return Config{}, fmt.Errorf("read config: %w", err)
	}

	allowedKeys := map[string]bool{
		"THRESHOLD_PERCENT": true,
		"MOUNT_POINTS":      true,
		"SMTP_HOST":         true,
		"SMTP_PORT":         true,
		"SMTP_USERNAME":     true,
		"SMTP_PASSWORD":     true,
		"EMAIL_FROM":        true,
		"EMAIL_TO":          true,
	}

	for key := range values {
		if !allowedKeys[key] {
			return Config{}, fmt.Errorf("unknown config key %q", key)
		}
	}

	required := []string{
		"THRESHOLD_PERCENT",
		"MOUNT_POINTS",
		"SMTP_HOST",
		"SMTP_PORT",
		"SMTP_USERNAME",
		"SMTP_PASSWORD",
		"EMAIL_FROM",
		"EMAIL_TO",
	}

	for _, key := range required {
		if values[key] == "" {
			return Config{}, fmt.Errorf(
				"missing required config key %q", key,
			)
		}
	}

	threshold, err := strconv.ParseFloat(
		values["THRESHOLD_PERCENT"], 64,
	)
	if err != nil || threshold <= 0 || threshold > 100 {
		return Config{}, fmt.Errorf(
			"THRESHOLD_PERCENT must be greater than 0 and at most 100",
		)
	}

	port, err := strconv.Atoi(values["SMTP_PORT"])
	if err != nil || port < 1 || port > 65535 {
		return Config{}, fmt.Errorf("SMTP_PORT must be between 1 and 65535")
	}

	mountPoints := strings.Split(values["MOUNT_POINTS"], ",")
	for i, mountPoint := range mountPoints {
		mountPoints[i] = strings.TrimSpace(mountPoint)
		if mountPoints[i] == "" || !strings.HasPrefix(mountPoints[i], "/") {
			return Config{}, fmt.Errorf(
				"invalid mount point %q", mountPoints[i],
			)
		}
	}

	return Config{
		ThresholdPercent: threshold,
		MountPoints:      mountPoints,
		SMTPHost:         values["SMTP_HOST"],
		SMTPPort:         values["SMTP_PORT"],
		SMTPUsername:     values["SMTP_USERNAME"],
		SMTPPassword:     values["SMTP_PASSWORD"],
		EmailFrom:        values["EMAIL_FROM"],
		EmailTo:          values["EMAIL_TO"],
	}, nil
}
