package api

import (
	"context"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"

	"routeguard/internal/config"
	"routeguard/internal/vpn"
	"routeguard/internal/routing"
	"routeguard/internal/dns"
	"routeguard/internal/dpi"
	"routeguard/internal/system"
)

// Server - API сервер
type Server struct {
	config  config.APIConfig
	logger  *zap.Logger
	router  *gin.Engine
	server  *http.Server
	vpn     *vpn.Manager
	routing *routing.Engine
	dns     *dns.Server
	dpi     *dpi.Bypass
	system  *system.Service
}

// Dependencies - зависимости API
type Dependencies struct {
	Logger  *zap.Logger
	VPN     *vpn.Manager
	Routing *routing.Engine
	DNS     *dns.Server
	DPI     *dpi.Bypass
	System  *system.Service
}

// NewServer - создание нового API сервера
func NewServer(cfg config.APIConfig, deps Dependencies) *Server {
	// Установка режима Gin
	if cfg.Token == "" {
		gin.SetMode(gin.ReleaseMode)
	}

	s := &Server{
		config:  cfg,
		logger:  deps.Logger,
		router:  gin.New(),
		vpn:     deps.VPN,
		routing: deps.Routing,
		dns:     deps.DNS,
		dpi:     deps.DPI,
		system:  deps.System,
	}

	s.setupMiddleware()
	s.setupRoutes()
	s.setupStaticRoutes()

	return s
}

// setupMiddleware - настройка middleware
func (s *Server) setupMiddleware() {
	// Логгер
	s.router.Use(gin.LoggerWithWriter(gin.DefaultWriter, "/health"))

	// Recovery
	s.router.Use(gin.Recovery())

	// CORS
	if s.config.CORS {
		s.router.Use(corsMiddleware(s.config))
	}

	// Rate limiting
	s.router.Use(rateLimitMiddleware(s.config.Token))

	// Auth middleware для защищённых routes
	s.router.Use(authMiddleware(s.config.Token))
}

// setupRoutes - настройка маршрутов
func (s *Server) setupRoutes() {
	// Health check
	s.router.GET("/health", s.healthCheck)

	// API v1
	v1 := s.router.Group("/api/v1")
	{
		// VPN endpoints
		vpn := v1.Group("/vpn")
		{
			vpn.GET("/profiles", s.getProfiles)
			vpn.POST("/profiles", s.createProfile)
			vpn.PUT("/profiles/:id", s.updateProfile)
			vpn.DELETE("/profiles/:id", s.deleteProfile)
			vpn.POST("/profiles/:id/connect", s.connectProfile)
			vpn.POST("/profiles/:id/disconnect", s.disconnectProfile)
			vpn.GET("/profiles/:id/status", s.getProfileStatus)
			vpn.POST("/import", s.importProfile)
			vpn.POST("/export", s.exportProfile)
		}

		// Routing endpoints
		routing := v1.Group("/routing")
		{
			routing.GET("/rules", s.getRules)
			routing.POST("/rules", s.createRule)
			routing.PUT("/rules/:id", s.updateRule)
			routing.DELETE("/rules/:id", s.deleteRule)
			routing.GET("/stats", s.getRoutingStats)
			routing.POST("/geoip/update", s.updateGeoIP)
		}

		// DNS endpoints
		dns := v1.Group("/dns")
		{
			dns.GET("/settings", s.getDNSSettings)
			dns.PUT("/settings", s.updateDNSSettings)
			dns.GET("/query-log", s.getQueryLog)
			dns.GET("/stats", s.getDNSStats)
			dns.POST("/cache/clear", s.clearDNSCache)
			dns.POST("/test", s.testDNS)
		}

		// DPI endpoints
		dpi := v1.Group("/dpi")
		{
			dpi.GET("/settings", s.getDPISettings)
			dpi.PUT("/settings", s.updateDPISettings)
			dpi.GET("/stats", s.getDPIStats)
			dpi.POST("/test", s.testDPI)
		}

		// System endpoints
		system := v1.Group("/system")
		{
			system.GET("/status", s.getSystemStatus)
			system.GET("/logs", s.getLogs)
			system.POST("/backup", s.createBackup)
			system.POST("/restore", s.restoreBackup)
			system.POST("/restart", s.restartService)
			system.GET("/update/check", s.checkUpdate)
			system.POST("/update/install", s.installUpdate)
		}

		// Settings
		v1.GET("/settings", s.getSettings)
		v1.PUT("/settings", s.updateSettings)
	}
}

// setupStaticRoutes - настройка статических файлов
func (s *Server) setupStaticRoutes() {
	s.router.StaticFS("/static/", http.Dir("./static"))
}

// Start - запуск сервера
func (s *Server) Start(addr string) error {
	s.server = &http.Server{
		Addr:         addr,
		Handler:      s.router,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	return s.server.ListenAndServe()
}

// Shutdown - корректная остановка сервера
func (s *Server) Shutdown(ctx context.Context) error {
	if s.server != nil {
		return s.server.Shutdown(ctx)
	}
	return nil
}

// Health check handler
func (s *Server) healthCheck(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"status":    "ok",
		"timestamp": time.Now().Unix(),
	})
}

// Заглушки для handlers (будут реализованы в отдельных файлах)

func (s *Server) getProfiles(c *gin.Context)          { c.JSON(200, gin.H{"profiles": []interface{}{}}) }
func (s *Server) createProfile(c *gin.Context)        { c.JSON(200, gin.H{"id": "new"}) }
func (s *Server) updateProfile(c *gin.Context)        { c.JSON(200, gin.H{"updated": true}) }
func (s *Server) deleteProfile(c *gin.Context)        { c.JSON(200, gin.H{"deleted": true}) }
func (s *Server) connectProfile(c *gin.Context)       { c.JSON(200, gin.H{"connected": true}) }
func (s *Server) disconnectProfile(c *gin.Context)    { c.JSON(200, gin.H{"disconnected": true}) }
func (s *Server) getProfileStatus(c *gin.Context)     { c.JSON(200, gin.H{"status": "disconnected"}) }
func (s *Server) importProfile(c *gin.Context)        { c.JSON(200, gin.H{"imported": true}) }
func (s *Server) exportProfile(c *gin.Context)        { c.JSON(200, gin.H{"exported": true}) }

func (s *Server) getRules(c *gin.Context)             { c.JSON(200, gin.H{"rules": []interface{}{}}) }
func (s *Server) createRule(c *gin.Context)           { c.JSON(200, gin.H{"id": "new"}) }
func (s *Server) updateRule(c *gin.Context)           { c.JSON(200, gin.H{"updated": true}) }
func (s *Server) deleteRule(c *gin.Context)           { c.JSON(200, gin.H{"deleted": true}) }
func (s *Server) getRoutingStats(c *gin.Context)      { c.JSON(200, gin.H{"stats": gin.H{}}) }
func (s *Server) updateGeoIP(c *gin.Context)          { c.JSON(200, gin.H{"updated": true}) }

func (s *Server) getDNSSettings(c *gin.Context)       { c.JSON(200, gin.H{"settings": gin.H{}}) }
func (s *Server) updateDNSSettings(c *gin.Context)    { c.JSON(200, gin.H{"updated": true}) }
func (s *Server) getQueryLog(c *gin.Context)          { c.JSON(200, gin.H{"logs": []interface{}{}}) }
func (s *Server) getDNSStats(c *gin.Context)          { c.JSON(200, gin.H{"stats": gin.H{}}) }
func (s *Server) clearDNSCache(c *gin.Context)        { c.JSON(200, gin.H{"cleared": true}) }
func (s *Server) testDNS(c *gin.Context)              { c.JSON(200, gin.H{"ok": true}) }

func (s *Server) getDPISettings(c *gin.Context)       { c.JSON(200, gin.H{"settings": gin.H{}}) }
func (s *Server) updateDPISettings(c *gin.Context)    { c.JSON(200, gin.H{"updated": true}) }
func (s *Server) getDPIStats(c *gin.Context)          { c.JSON(200, gin.H{"stats": gin.H{}}) }
func (s *Server) testDPI(c *gin.Context)              { c.JSON(200, gin.H{"ok": true}) }

func (s *Server) getSystemStatus(c *gin.Context)      { c.JSON(200, gin.H{"status": "running"}) }
func (s *Server) getLogs(c *gin.Context)              { c.JSON(200, gin.H{"logs": []string{}}) }
func (s *Server) createBackup(c *gin.Context)         { c.JSON(200, gin.H{"backup": "backup.json"}) }
func (s *Server) restoreBackup(c *gin.Context)        { c.JSON(200, gin.H{"restored": true}) }
func (s *Server) restartService(c *gin.Context)       { c.JSON(200, gin.H{"restarted": true}) }
func (s *Server) checkUpdate(c *gin.Context)          { c.JSON(200, gin.H{"available": false}) }
func (s *Server) installUpdate(c *gin.Context)        { c.JSON(200, gin.H{"installed": true}) }

func (s *Server) getSettings(c *gin.Context)          { c.JSON(200, gin.H{"settings": gin.H{}}) }
func (s *Server) updateSettings(c *gin.Context)       { c.JSON(200, gin.H{"updated": true}) }

// Middleware функции (будут реализованы отдельно)

func corsMiddleware(cfg config.APIConfig) gin.HandlerFunc {
	return func(c *gin.Context) {
		// Используем разрешённые origins из конфигурации
		origin := c.Request.Header.Get("Origin")
		allowed := false
		
		if len(cfg.AllowedOrigins) > 0 {
			for _, o := range cfg.AllowedOrigins {
				if o == "*" || o == origin {
					allowed = true
					break
				}
			}
			if allowed {
				c.Header("Access-Control-Allow-Origin", origin)
			}
		} else if cfg.CORS {
			// Если CORS включён но origins не указаны, разрешаем все
			c.Header("Access-Control-Allow-Origin", "*")
		}
		
		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Origin, Content-Type, Authorization, X-API-Token")
		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}
		c.Next()
	}
}

func rateLimitMiddleware(token string) gin.HandlerFunc {
	// Простая реализация rate limiting
	// В продакшене использовать redis или similar
	_ = token
	return func(c *gin.Context) {
		c.Next()
	}
}

func authMiddleware(token string) gin.HandlerFunc {
	return func(c *gin.Context) {
		// Пропускать health check
		if c.Request.URL.Path == "/health" {
			c.Next()
			return
		}

		// Пропускать static files без аутентификации
		if len(c.Request.URL.Path) > 7 && c.Request.URL.Path[:7] == "/static" {
			c.Next()
			return
		}

		// Пропускать корневой путь для отдачи index.html
		if c.Request.URL.Path == "/" {
			c.Next()
			return
		}

		// Проверка API токена
		apiToken := c.GetHeader("X-API-Token")
		if apiToken == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Требуется API токен"})
			c.Abort()
			return
		}

		if apiToken != token {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Неверный токен"})
			c.Abort()
			return
		}

		c.Next()
	}
}
