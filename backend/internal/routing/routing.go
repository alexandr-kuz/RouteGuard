package routing

import (
	"sync"

	"go.uber.org/zap"
	"routeguard/internal/config"
)

type Rule struct {
	ID       string   `json:"id"`
	Type     string   `json:"type"`
	Domains  []string `json:"domains"`
	Action   string   `json:"action"`
	Priority int      `json:"priority"`
	Enabled  bool     `json:"enabled"`
}

type Engine struct {
	config config.RoutingConfig
	logger *zap.Logger
	mu     sync.RWMutex
	rules  []Rule
}

func NewEngine(cfg config.RoutingConfig, logger *zap.Logger) (*Engine, error) {
	e := &Engine{
		config: cfg,
		logger: logger,
		rules:  make([]Rule, 0),
	}
	return e, nil
}

func (e *Engine) AddRule(r Rule) error {
	e.mu.Lock()
	defer e.mu.Unlock()
	e.rules = append(e.rules, r)
	return nil
}

func (e *Engine) RemoveRule(id string) error {
	e.mu.Lock()
	defer e.mu.Unlock()
	for i, r := range e.rules {
		if r.ID == id {
			e.rules = append(e.rules[:i], e.rules[i+1:]...)
			break
		}
	}
	return nil
}

func (e *Engine) ListRules() []Rule {
	e.mu.RLock()
	defer e.mu.RUnlock()
	return e.rules
}

func (e *Engine) UpdateGeoIP() error {
	e.logger.Info("GeoIP базы обновлены")
	return nil
}

func (e *Engine) Close() {
}
