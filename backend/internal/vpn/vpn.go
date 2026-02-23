package vpn

import (
	"context"
	"sync"

	"go.uber.org/zap"
	"routeguard/internal/config"
)

type Profile struct {
	ID       string `json:"id"`
	Name     string `json:"name"`
	Type     string `json:"type"`
	Active   bool   `json:"active"`
	FilePath string `json:"file_path"`
}

type Manager struct {
	config   config.VPNConfig
	logger   *zap.Logger
	mu       sync.RWMutex
	profiles []Profile
	current  *Profile
	cancel   context.CancelFunc
}

func NewManager(cfg config.VPNConfig, logger *zap.Logger) (*Manager, error) {
	m := &Manager{
		config:   cfg,
		logger:   logger,
		profiles: make([]Profile, 0),
	}
	return m, nil
}

func (m *Manager) ListProfiles() []Profile {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.profiles
}

func (m *Manager) AddProfile(p Profile) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.profiles = append(m.profiles, p)
	return nil
}

func (m *Manager) RemoveProfile(id string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	for i, p := range m.profiles {
		if p.ID == id {
			m.profiles = append(m.profiles[:i], m.profiles[i+1:]...)
			break
		}
	}
	return nil
}

func (m *Manager) Connect(id string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	for i, p := range m.profiles {
		if p.ID == id {
			m.current = &m.profiles[i]
			return nil
		}
	}
	return nil
}

func (m *Manager) Disconnect() error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.current = nil
	return nil
}

func (m *Manager) Status() (string, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	if m.current != nil && m.current.Active {
		return "connected", nil
	}
	return "disconnected", nil
}

func (m *Manager) Close() {
	if m.cancel != nil {
		m.cancel()
	}
}
