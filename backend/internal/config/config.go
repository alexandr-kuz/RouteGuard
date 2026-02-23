package config

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/go-playground/validator/v10"
)

// Config - основная структура конфигурации
type Config struct {
	Version   string    `json:"version" validate:"required"`
	Installed time.Time `json:"installed_at"`

	API       APIConfig       `json:"api" validate:"required"`
	VPN       VPNConfig       `json:"vpn" validate:"required"`
	Routing   RoutingConfig   `json:"routing" validate:"required"`
	DNS       DNSConfig       `json:"dns" validate:"required"`
	DPI       DPIConfig       `json:"dpi" validate:"required"`
	Logging   LoggingConfig   `json:"logging" validate:"required"`
	Update    UpdateConfig    `json:"update" validate:"required"`
	Security  SecurityConfig  `json:"security" validate:"required"`
}

// APIConfig - конфигурация API сервера
type APIConfig struct {
	Host         string   `json:"host" validate:"required,ip"`
	Port         int      `json:"port" validate:"required,min=1,max=65535"`
	Token        string   `json:"token" validate:"required,min=32"`
	CORS         bool     `json:"cors"`
	AllowedOrigins []string `json:"allowed_origins"`
}

// VPNConfig - конфигурация VPN модуля
type VPNConfig struct {
	Enabled    bool   `json:"enabled"`
	Core       string `json:"core" validate:"oneof=sing-box xray"`
	ConfigDir  string `json:"config_dir"`
	AutoConnect bool  `json:"auto_connect"`
}

// RoutingConfig - конфигурация маршрутизации
type RoutingConfig struct {
	Enabled      bool   `json:"enabled"`
	Mode         string `json:"mode" validate:"oneof=domain geoip cidr mixed"`
	DefaultRoute string `json:"default_route" validate:"oneof=direct vpn"`
	RulesetsDir  string `json:"rulesets_dir"`
}

// DNSConfig - конфигурация DNS модуля
type DNSConfig struct {
	Enabled   bool     `json:"enabled"`
	Port      int      `json:"port" validate:"required,min=1,max=65535"`
	Upstream  string   `json:"upstream" validate:"required"`
	Bootstrap string   `json:"bootstrap"`
	CacheTTL  int      `json:"cache_ttl"` // секунды
	AdBlock   AdBlockConfig `json:"adblock"`
}

// AdBlockConfig - конфигурация блокировки рекламы
type AdBlockConfig struct {
	Enabled bool     `json:"enabled"`
	Lists   []string `json:"lists"`
}

// DPIConfig - конфигурация DPI обхода
type DPIConfig struct {
	Enabled         bool     `json:"enabled"`
	Mode            string   `json:"mode" validate:"oneof=auto manual"`
	BypassDomains   []string `json:"bypass_domains"`
}

// LoggingConfig - конфигурация логирования
type LoggingConfig struct {
	Level      string `json:"level" validate:"oneof=debug info warn error"`
	File       string `json:"file"`
	MaxSizeMB  int    `json:"max_size_mb"`
	MaxBackups int    `json:"max_backups"`
}

// UpdateConfig - конфигурация обновлений
type UpdateConfig struct {
	AutoCheck      bool   `json:"auto_check"`
	CheckInterval  string `json:"check_interval"`
	AutoInstall    bool   `json:"auto_install"`
	InstallWindow  string `json:"install_window"` // например "03:00-05:00"
}

// SecurityConfig - конфигурация безопасности
type SecurityConfig struct {
	RateLimit      int    `json:"rate_limit"` // запросов в минуту
	SessionTimeout string `json:"session_timeout"`
}

// Load - загрузка конфигурации из файла
func Load(path string) (*Config, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("чтение файла конфигурации: %w", err)
	}

	var cfg Config
	if err := json.Unmarshal(data, &cfg); err != nil {
		return nil, fmt.Errorf("парсинг JSON: %w", err)
	}

	// Валидация
	validate := validator.New()
	if err := validate.Struct(&cfg); err != nil {
		return nil, fmt.Errorf("валидация конфигурации: %w", err)
	}

	// Установка значений по умолчанию
	setDefaults(&cfg)

	// Создание директорий если не существуют
	if err := ensureDirectories(&cfg); err != nil {
		return nil, fmt.Errorf("создание директорий: %w", err)
	}

	return &cfg, nil
}

// setDefaults - установка значений по умолчанию
func setDefaults(cfg *Config) {
	if cfg.API.Host == "" {
		cfg.API.Host = "0.0.0.0"
	}
	if cfg.Logging.Level == "" {
		cfg.Logging.Level = "info"
	}
	if cfg.Logging.MaxSizeMB == 0 {
		cfg.Logging.MaxSizeMB = 10
	}
	if cfg.Logging.MaxBackups == 0 {
		cfg.Logging.MaxBackups = 3
	}
	if cfg.DNS.CacheTTL == 0 {
		cfg.DNS.CacheTTL = 300
	}
	if cfg.Security.RateLimit == 0 {
		cfg.Security.RateLimit = 100
	}
	if cfg.Security.SessionTimeout == "" {
		cfg.Security.SessionTimeout = "24h"
	}
}

// ensureDirectories - создание необходимых директорий
func ensureDirectories(cfg *Config) error {
	dirs := []string{
		filepath.Dir(cfg.Logging.File),
		cfg.VPN.ConfigDir,
		cfg.Routing.RulesetsDir,
	}

	for _, dir := range dirs {
		if dir != "" {
			if err := os.MkdirAll(dir, 0755); err != nil {
				return err
			}
		}
	}

	return nil
}

// Save - сохранение конфигурации в файл
func (cfg *Config) Save(path string) error {
	data, err := json.MarshalIndent(cfg, "", "    ")
	if err != nil {
		return err
	}

	return os.WriteFile(path, data, 0600)
}

// GetCheckInterval - получение интервала проверки обновлений
func (cfg *UpdateConfig) GetCheckInterval() time.Duration {
	d, err := time.ParseDuration(cfg.CheckInterval)
	if err != nil {
		return 24 * time.Hour
	}
	return d
}

// GetSessionTimeout - получение таймаута сессии
func (cfg *SecurityConfig) GetSessionTimeout() time.Duration {
	d, err := time.ParseDuration(cfg.SessionTimeout)
	if err != nil {
		return 24 * time.Hour
	}
	return d
}
