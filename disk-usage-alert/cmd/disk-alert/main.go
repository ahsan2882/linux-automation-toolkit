package main

import (
	"flag"
	"log"
	"os"

	"disk-usage-alert/internal/alert"
	"disk-usage-alert/internal/config"
	"disk-usage-alert/internal/filesystem"
	"disk-usage-alert/internal/monitor"
)

func main() {
	configPath := flag.String(
		"config",
		"config/disk-alert.conf",
		"Path to the disk alert configuration file",
	)
	flag.Parse()

	cfg, err := config.Load(*configPath)
	if err != nil {
		log.Printf("ERROR: %v", err)
		os.Exit(1)
	}

	emailSender := alert.NewEmailSender(cfg)

	diskMonitor := monitor.New(
		cfg.ThresholdPercent,
		cfg.MountPoints,
		filesystem.Reader{},
		emailSender,
	)

	if err := diskMonitor.Run(); err != nil {
		log.Printf("ERROR: %v", err)
		os.Exit(1)
	}
}
