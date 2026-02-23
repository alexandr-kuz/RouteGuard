package dpi

import (
	"sync"

	"go.uber.org/zap"
	"routeguard/internal/config"
)

type Bypass struct {
	config  config.DPIConfig
	logger  *zap.Logger
	mu      sync.RWMutex
	running bool
}

func NewBypass(cfg config.DPIConfig, logger *zap.Logger) (*Bypass, error) {
	b := &Bypass{
		config:  cfg,
		logger:  logger,
		running: cfg.Enabled,
	}
	return b, nil
}

func (b *Bypass) Start() error {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.running = true
	b.logger.Info("DPI обход запущен")
	return nil
}

func (b *Bypass) Stop() {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.running = false
	b.logger.Info("DPI обход остановлен")
}

func (b *Bypass) Status() string {
	b.mu.RLock()
	defer b.mu.RUnlock()
	if b.running {
		return "running"
	}
	return "stopped"
}
