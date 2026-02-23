.PHONY: help build build-backend build-frontend build-ipk clean test install dev

# Переменные
VERSION ?= 0.1.0
GO ?= go
GOPATH ?= $(shell go env GOPATH)
BACKEND_DIR := backend
FRONTEND_DIR := frontend
DIST_DIR := dist
SCRIPTS_DIR := scripts

# Цвета для вывода
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
NC := \033[0m

help:
	@echo "$(BLUE)╔════════════════════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║   RouteGuard Build System                          ║$(NC)"
	@echo "$(BLUE)╚════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "  $(GREEN)build$(NC)         - Сборка всех компонентов"
	@echo "  $(GREEN)build-backend$(NC) - Сборка backend (Go)"
	@echo "  $(GREEN)build-frontend$(NC) - Сборка frontend (Vue 3)"
	@echo "  $(GREEN)build-ipk$(NC)     - Создание OPKG пакета"
	@echo "  $(GREEN)clean$(NC)         - Очистка артефактов"
	@echo "  $(GREEN)test$(NC)          - Запуск тестов"
	@echo "  $(GREEN)dev$(NC)           - Запуск dev-серверов"
	@echo ""

build: build-backend build-frontend
	@echo "$(GREEN)✓$(NC) Сборка завершена"

build-backend:
	@echo "$(BLUE)━━━ Сборка backend ━━━$(NC)"
	cd $(BACKEND_DIR) && $(GO) build \
		-ldflags="-s -w -extldflags '-static'" \
		-trimpath \
		-o ../$(DIST_DIR)/routeguard \
		./main.go
	@echo "$(GREEN)✓$(NC) Backend собран"

build-backend-all:
	@echo "$(BLUE)━━━ Кросс-компиляция backend ━━━$(NC)"
	mkdir -p $(DIST_DIR)/mips $(DIST_DIR)/arm $(DIST_DIR)/amd64
	
	# MIPS
	CGO_ENABLED=0 GOOS=linux GOARCH=mips GOFLAGS=-buildvcs=false \
		$(GO) build -ldflags="-s -w -extldflags '-static'" -trimpath \
		-o $(DIST_DIR)/mips/routeguard ./$(BACKEND_DIR)/main.go
	@echo "$(GREEN)✓$(NC) MIPS собран"
	
	# ARM
	CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=7 GOFLAGS=-buildvcs=false \
		$(GO) build -ldflags="-s -w -extldflags '-static'" -trimpath \
		-o $(DIST_DIR)/arm/routeguard ./$(BACKEND_DIR)/main.go
	@echo "$(GREEN)✓$(NC) ARM собран"
	
	# AMD64
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 GOFLAGS=-buildvcs=false \
		$(GO) build -ldflags="-s -w -extldflags '-static'" -trimpath \
		-o $(DIST_DIR)/amd64/routeguard ./$(BACKEND_DIR)/main.go
	@echo "$(GREEN)✓$(NC) AMD64 собран"

build-frontend:
	@echo "$(BLUE)━━━ Сборка frontend ━━━$(NC)"
	cd $(FRONTEND_DIR) && npm install && npm run build
	@echo "$(GREEN)✓$(NC) Frontend собран"

build-ipk: build-backend-all
	@echo "$(BLUE)━━━ Создание OPKG пакетов ━━━$(NC)"
	@bash $(SCRIPTS_DIR)/build/build-ipk.sh $(VERSION)
	@echo "$(GREEN)✓$(NC) OPKG пакеты созданы"

clean:
	@echo "$(YELLOW)━━━ Очистка ━━━$(NC)"
	rm -rf $(DIST_DIR)
	rm -rf $(BACKEND_DIR)/routeguard
	rm -rf $(FRONTEND_DIR)/dist
	rm -rf $(FRONTEND_DIR)/node_modules
	@echo "$(GREEN)✓$(NC) Очистка завершена"

test:
	@echo "$(BLUE)━━━ Запуск тестов ━━━$(NC)"
	cd $(BACKEND_DIR) && $(GO) test -v ./...
	@echo "$(GREEN)✓$(NC) Тесты завершены"

dev:
	@echo "$(BLUE)━━━ Запуск dev-режима ━━━$(NC)"
	@echo "Backend: http://localhost:8080"
	@echo "Frontend: http://localhost:3000"
	@echo ""
	cd $(BACKEND_DIR) && $(GO) run ./main.go &
	cd $(FRONTEND_DIR) && npm run dev

install: build
	@echo "$(BLUE)━━━ Установка локально ━━━$(NC)"
	sudo cp $(DIST_DIR)/routeguard /opt/bin/
	sudo chmod +x /opt/bin/routeguard
	@echo "$(GREEN)✓$(NC) Установка завершена"

release: clean build-ipk
	@echo "$(GREEN)✓$(NC) Релиз $(VERSION) готов"
	@ls -la $(DIST_DIR)

version:
	@echo $(VERSION)
