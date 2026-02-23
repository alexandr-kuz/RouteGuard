package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"routeguard/internal/api"
	"routeguard/internal/config"
	"routeguard/internal/logging"
	"routeguard/internal/vpn"
	"routeguard/internal/routing"
	"routeguard/internal/dns"
	"routeguard/internal/dpi"
	"routeguard/internal/system"

	"go.uber.org/zap"
	_ "go.uber.org/automaxprocs"
)

const (
	appName    = "routeguard"
	appVersion = "0.1.0"
)

func main() {
	// Парсинг флагов командной строки
	configPath := flag.String("config", "/opt/etc/routeguard/config.json", "Путь к конфигурационному файлу")
	showVersion := flag.Bool("version", false, "Показать версию")
	flag.Parse()

	if *showVersion {
		fmt.Printf("%s v%s\n", appName, appVersion)
		os.Exit(0)
	}

	// Загрузка конфигурации
	cfg, err := config.Load(*configPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Ошибка загрузки конфигурации: %v\n", err)
		os.Exit(1)
	}

	// Инициализация логгера
	logger, err := logging.New(cfg.Logging)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Ошибка инициализации логгера: %v\n", err)
		os.Exit(1)
	}
	defer logger.Sync()

	logger.Info("запуск RouteGuard",
		zap.String("version", appVersion),
		zap.String("config", *configPath),
	)

	// Инициализация модулей
	// VPN модуль
	var vpnManager *vpn.Manager
	if cfg.VPN.Enabled {
		vpnManager, err = vpn.NewManager(cfg.VPN, logger)
		if err != nil {
			logger.Error("ошибка инициализации VPN менеджера", zap.Error(err))
		} else {
			logger.Info("VPN модуль инициализирован")
		}
	}

	// Routing модуль
	var routingEngine *routing.Engine
	if cfg.Routing.Enabled {
		routingEngine, err = routing.NewEngine(cfg.Routing, logger)
		if err != nil {
			logger.Error("ошибка инициализации routing движка", zap.Error(err))
		} else {
			logger.Info("Routing модуль инициализирован")
		}
	}

	// DNS модуль
	var dnsServer *dns.Server
	if cfg.DNS.Enabled {
		dnsServer, err = dns.NewServer(cfg.DNS, logger)
		if err != nil {
			logger.Error("ошибка инициализации DNS сервера", zap.Error(err))
		} else {
			logger.Info("DNS модуль инициализирован")
		}
	}

	// DPI модуль
	var dpiBypass *dpi.Bypass
	if cfg.DPI.Enabled {
		dpiBypass, err = dpi.NewBypass(cfg.DPI, logger)
		if err != nil {
			logger.Error("ошибка инициализации DPI обхода", zap.Error(err))
		} else {
			logger.Info("DPI модуль инициализирован")
		}
	}

	// System модуль
	systemService := system.NewService(appName, appVersion, logger)

	// API сервер
	apiServer := api.NewServer(cfg.API, api.Dependencies{
		Logger:  logger,
		VPN:     vpnManager,
		Routing: routingEngine,
		DNS:     dnsServer,
		DPI:     dpiBypass,
		System:  systemService,
	})

	// Запуск API сервера
	go func() {
		addr := fmt.Sprintf("%s:%d", cfg.API.Host, cfg.API.Port)
		logger.Info("запуск API сервера", zap.String("address", addr))
		if err := apiServer.Start(addr); err != nil {
			logger.Fatal("ошибка API сервера", zap.Error(err))
		}
	}()

	// Обработка сигналов
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	logger.Info("RouteGuard готов к работе")

	// Ожидание сигнала завершения
	sig := <-sigChan
	logger.Info("получен сигнал завершения", zap.String("signal", sig.String()))

	//Graceful shutdown
	ctx, cancel := context.WithTimeout(context.Background(), system.DefaultShutdownTimeout)
	defer cancel()

	if vpnManager != nil {
		vpnManager.Close()
	}
	if routingEngine != nil {
		routingEngine.Close()
	}
	if dnsServer != nil {
		dnsServer.Stop()
	}
	if dpiBypass != nil {
		dpiBypass.Stop()
	}

	if err := apiServer.Shutdown(ctx); err != nil {
		logger.Error("ошибка при завершении работы API", zap.Error(err))
	}

	logger.Info("RouteGuard завершил работу")
}
