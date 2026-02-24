package dns

import (
	"sync"

	"go.uber.org/zap"
	"routeguard/internal/config"
)

type Server struct {
	config  config.DNSConfig
	logger  *zap.Logger
	mu      sync.RWMutex
	running bool
}

func NewServer(cfg config.DNSConfig, logger *zap.Logger) (*Server, error) {
	s := &Server{
		config:  cfg,
		logger:  logger,
		running: false, // Сервер ещё не запущен
	}
	return s, nil
}

func (s *Server) Start() error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.running = true
	s.logger.Info("DNS сервер запущен")
	return nil
}

func (s *Server) Stop() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.running = false
	s.logger.Info("DNS сервер остановлен")
}

func (s *Server) Status() string {
	s.mu.RLock()
	defer s.mu.RUnlock()
	if s.running {
		return "running"
	}
	return "stopped"
}
