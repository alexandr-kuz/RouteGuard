package system

import (
	"time"

	"go.uber.org/zap"
)

const DefaultShutdownTimeout = 30 * time.Second

type Info struct {
	Name       string `json:"name"`
	Version    string `json:"version"`
	Uptime     string `json:"uptime"`
	MemoryUsed string `json:"memory_used"`
	DiskUsed   string `json:"disk_used"`
	CPUUsage   string `json:"cpu_usage"`
}

type Service struct {
	name    string
	version string
	logger  *zap.Logger
	started time.Time
}

func NewService(name, version string, logger *zap.Logger) *Service {
	return &Service{
		name:    name,
		version: version,
		logger:  logger,
		started: time.Now(),
	}
}

func (s *Service) Info() Info {
	uptime := time.Since(s.started)
	return Info{
		Name:       s.name,
		Version:    s.version,
		Uptime:     uptime.String(),
		MemoryUsed: "N/A",
		DiskUsed:   "N/A",
		CPUUsage:   "N/A",
	}
}

func (s *Service) Health() map[string]string {
	return map[string]string{
		"status": "healthy",
	}
}
