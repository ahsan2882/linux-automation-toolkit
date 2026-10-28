package filesystem

import (
	"fmt"
	"syscall"
)

type Usage struct {
	MountPoint     string
	UsedBytes      uint64
	AvailableBytes uint64
	UsedPercent    float64
}

type Reader struct{}

func (Reader) GetUsage(mountPoint string) (Usage, error) {
	var stat syscall.Statfs_t

	if err := syscall.Statfs(mountPoint, &stat); err != nil {
		return Usage{}, fmt.Errorf(
			"stat filesystem %s: %w", mountPoint, err,
		)
	}

	if stat.Blocks == 0 {
		return Usage{}, fmt.Errorf(
			"filesystem %s has zero blocks", mountPoint,
		)
	}

	usedBlocks := stat.Blocks - stat.Bfree
	availableBlocks := stat.Bavail

	// Match the general behavior of df's Use%:
	// used / (used + available to unprivileged users).
	effectiveTotal := usedBlocks + availableBlocks
	if effectiveTotal == 0 {
		return Usage{}, fmt.Errorf(
			"filesystem %s has no measurable capacity", mountPoint,
		)
	}

	blockSize := uint64(stat.Bsize)

	return Usage{
		MountPoint:     mountPoint,
		UsedBytes:      usedBlocks * blockSize,
		AvailableBytes: availableBlocks * blockSize,
		UsedPercent:    float64(usedBlocks) / float64(effectiveTotal) * 100,
	}, nil
}
