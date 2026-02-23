#!/bin/sh
# RouteGuard Installer
# Установка: curl -sL https://github.com/username/routeguard/releases/latest/download/install.sh | sh
#
# Документация: https://github.com/username/routeguard

set -e

# =============================================================================
# КОНФИГУРАЦИЯ
# =============================================================================

VERSION="${RG_VERSION:-latest}"
REPO="${RG_REPO:-username/routeguard}"
BASE_URL="https://github.com/${REPO}/releases"

# Пути установки
INSTALL_DIR="/opt/etc/routeguard"
BIN_DIR="/opt/bin"
LOG_DIR="/opt/var/log/routeguard"
DATA_DIR="/opt/var/lib/routeguard"
SERVICE_FILE="/opt/etc/init.d/S50rguard"
CONFIG_FILE="$INSTALL_DIR/config.json"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# =============================================================================
# ФУНКЦИИ ЛОГИРОВАНИЯ
# =============================================================================

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()    { echo -e "${CYAN}━━━ $1 ━━━${NC}"; }

# =============================================================================
# ПРОВЕРКА ОКРУЖЕНИЯ
# =============================================================================

check_prerequisites() {
    log_step "Проверка окружения"
    
    # Проверка Entware
    if [ ! -f "/opt/bin/opkg" ]; then
        log_error "Entware не найден. Установите Entware на ваш роутер."
        log_info "Инструкция: https://kb.keenetic.ru/hc/ru/articles/360000202345"
        exit 1
    fi
    log_success "Entware найден"
    
    # Проверка архитектуры
    ARCH=$(uname -m)
    case "$ARCH" in
        mips|mipsel)
            TARGET="mips"
            ;;
        armv7l|armv6l|aarch64)
            TARGET="arm"
            ;;
        x86_64|amd64|i686)
            TARGET="amd64"
            ;;
        *)
            log_error "Неподдерживаемая архитектура: $ARCH"
            exit 1
            ;;
    esac
    log_success "Архитектура: $ARCH ($TARGET)"
    
    # Проверка свободной памяти
    FREE_MEM=$(free -m 2>/dev/null | awk '/^Mem:/ {print $7}' || echo "100")
    if [ "$FREE_MEM" -lt 50 ]; then
        log_warn "Мало свободной памяти: ${FREE_MEM}MB (рекомендуется 100MB+)"
    else
        log_success "Свободная память: ${FREE_MEM}MB"
    fi
    
    # Проверка прав root
    if [ "$(id -u)" != "0" ]; then
        log_error "Требуются права root"
        exit 1
    fi
    log_success "Права root подтверждены"
    
    # Проверка места на диске
    FREE_SPACE=$(df -m /opt 2>/dev/null | awk 'NR==2 {print $4}' || echo "100")
    if [ "$FREE_SPACE" -lt 50 ]; then
        log_warn "Мало места на /opt: ${FREE_SPACE}MB (рекомендуется 100MB+)"
    else
        log_success "Свободное место: ${FREE_SPACE}MB"
    fi
}

# =============================================================================
# ЗАГРУЗКА БИНАРНИКОВ
# =============================================================================

download_binaries() {
    log_step "Загрузка RouteGuard"
    
    # Определение версии и URL
    if [ "$VERSION" = "latest" ]; then
        log_info "Поиск последней версии..."
        VERSION=$(curl -s "https://api.github.com/repos/${REPO}/releases/latest" \
                  | grep '"tag_name":' | cut -d'"' -f4 | sed 's/^v//')
        if [ -z "$VERSION" ]; then
            log_error "Не удалось получить последнюю версию"
            exit 1
        fi
    fi
    log_info "Версия: $VERSION"
    
    # Формирование URL
    FILENAME="routeguard-${TARGET}.tar.gz"
    URL="${BASE_URL}/download/v${VERSION}/${FILENAME}"
    CHECKSUM_URL="${URL}.sha256"
    
    log_info "Загрузка: $URL"
    
    # Временная директория
    TMP_DIR="/tmp/routeguard-install-$$"
    mkdir -p "$TMP_DIR"
    
    # Загрузка архива
    if ! curl -sL "$URL" -o "$TMP_DIR/routeguard.tar.gz"; then
        log_error "Не удалось загрузить бинарник"
        rm -rf "$TMP_DIR"
        exit 1
    fi
    log_success "Бинарник загружен"
    
    # Загрузка checksum
    if curl -sL "$CHECKSUM_URL" -o "$TMP_DIR/checksum.sha256" 2>/dev/null; then
        log_info "Проверка контрольной суммы..."
        cd "$TMP_DIR"
        if ! sha256sum -c checksum.sha256 > /dev/null 2>&1; then
            log_error "Неверная контрольная сумма! Возможна атака."
            rm -rf "$TMP_DIR"
            exit 1
        fi
        log_success "Контрольная сумма верна"
    else
        log_warn "Не удалось загрузить checksum, пропускаем проверку"
    fi
    
    # Распаковка
    log_info "Распаковка..."
    tar -xzf routeguard.tar.gz -C "$TMP_DIR"
    
    # Установка бинарника
    cp "$TMP_DIR/routeguard" "$BIN_DIR/"
    chmod +x "$BIN_DIR/routeguard"
    
    # Очистка
    rm -rf "$TMP_DIR"
    
    log_success "Бинарники установлены в $BIN_DIR"
}

# =============================================================================
# УСТАНОВКА ЗАВИСИМОСТЕЙ
# =============================================================================

install_dependencies() {
    log_step "Установка зависимостей"
    
    log_info "Обновление списков пакетов..."
    opkg update
    
    # sing-box (основное VPN-ядро)
    if command -v sing-box >/dev/null 2>&1; then
        log_success "sing-box уже установлен"
    else
        log_info "Установка sing-box..."
        if opkg install sing-box; then
            log_success "sing-box установлен"
        else
            log_warn "sing-box не установлен (опционально)"
        fi
    fi
    
    # smartdns (лёгкий DNS-сервер)
    if command -v smartdns >/dev/null 2>&1; then
        log_success "smartdns уже установлен"
    else
        log_info "Установка smartdns..."
        if opkg install smartdns; then
            log_success "smartdns установлен"
        else
            log_warn "smartdns не установлен (опционально)"
        fi
    fi
    
    # ByeDPI (обход DPI)
    if command -v byedpi >/dev/null 2>&1; then
        log_success "ByeDPI уже установлен"
    else
        log_info "Установка ByeDPI..."
        if opkg install byedpi; then
            log_success "ByeDPI установлен"
        else
            log_warn "ByeDPI не установлен (опционально)"
        fi
    fi
    
    # curl (для внутренних запросов)
    if ! command -v curl >/dev/null 2>&1; then
        log_info "Установка curl..."
        opkg install curl
    fi
    log_success "curl установлен"
    
    # openssl (для генерации токенов)
    if ! command -v openssl >/dev/null 2>&1; then
        log_info "Установка openssl..."
        opkg install openssl
    fi
    log_success "openssl установлен"
}

# =============================================================================
# СОЗДАНИЕ ДИРЕКТОРИЙ
# =============================================================================

create_directories() {
    log_step "Создание директорий"
    
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR/configs"
    mkdir -p "$INSTALL_DIR/profiles"
    mkdir -p "$INSTALL_DIR/rulesets"
    mkdir -p "$INSTALL_DIR/certs"
    mkdir -p "$LOG_DIR"
    mkdir -p "$DATA_DIR"
    mkdir -p "$DATA_DIR/geoip"
    mkdir -p "$DATA_DIR/geosite"
    mkdir -p "$DATA_DIR/backups"
    
    # Установка правильных прав
    chmod 755 "$INSTALL_DIR"
    chmod 755 "$LOG_DIR"
    chmod 700 "$DATA_DIR"
    chmod 700 "$INSTALL_DIR/certs"
    
    log_success "Директории созданы"
}

# =============================================================================
# ГЕНЕРАЦИЯ КОНФИГУРАЦИИ
# =============================================================================

generate_config() {
    log_step "Генерация конфигурации"
    
    # Генерация API токена
    API_TOKEN=$(openssl rand -hex 32)
    
    # Определение локального IP
    LOCAL_IP=$(hostname -i 2>/dev/null || echo "192.168.1.1")
    
    # Создание config.json
    cat > "$CONFIG_FILE" << EOF
{
    "version": "$VERSION",
    "installed_at": "$(date -Iseconds)",
    
    "api": {
        "host": "0.0.0.0",
        "port": 8080,
        "token": "$API_TOKEN",
        "cors": true,
        "allowed_origins": ["http://$LOCAL_IP:8080"]
    },
    
    "vpn": {
        "enabled": true,
        "core": "sing-box",
        "config_dir": "$INSTALL_DIR/profiles",
        "auto_connect": false
    },
    
    "routing": {
        "enabled": true,
        "mode": "domain",
        "default_route": "direct",
        "rulesets_dir": "$INSTALL_DIR/rulesets"
    },
    
    "dns": {
        "enabled": true,
        "port": 53,
        "upstream": "tls://1.1.1.1",
        "bootstrap": "1.1.1.1",
        "cache_ttl": 300,
        "adblock": {
            "enabled": false,
            "lists": []
        }
    },
    
    "dpi": {
        "enabled": false,
        "mode": "auto",
        "bypass_domains": []
    },
    
    "logging": {
        "level": "info",
        "file": "$LOG_DIR/routeguard.log",
        "max_size_mb": 10,
        "max_backups": 3
    },
    
    "update": {
        "auto_check": true,
        "check_interval": "24h",
        "auto_install": false
    },
    
    "security": {
        "rate_limit": 100,
        "session_timeout": "24h"
    }
}
EOF
    
    # Сохранение токена в отдельный файл
    echo "$API_TOKEN" > "$INSTALL_DIR/.api_token"
    chmod 600 "$INSTALL_DIR/.api_token"
    
    # Сохранение информации для вывода
    echo "$LOCAL_IP" > "$INSTALL_DIR/.local_ip"
    
    log_success "Конфигурация создана"
}

# =============================================================================
# РЕГИСТРАЦИЯ СЕРВИСА
# =============================================================================

register_service() {
    log_step "Регистрация сервиса"
    
    cat > "$SERVICE_FILE" << 'EOF'
#!/bin/sh
# RouteGuard Service Script
# Usage: /opt/etc/init.d/S50rguard {start|stop|restart|status}

NAME="routeguard"
BIN="/opt/bin/routeguard"
CONFIG="/opt/etc/routeguard/config.json"
PIDFILE="/var/run/$NAME.pid"
LOGDIR="/opt/var/log/routeguard"

# Проверка существования бинарника
if [ ! -x "$BIN" ]; then
    echo "Error: $BIN not found or not executable"
    exit 1
fi

start() {
    if pidof "$NAME" > /dev/null; then
        echo "$NAME is already running"
        return 0
    fi
    
    echo "Starting $NAME..."
    
    # Создание директории для логов если не существует
    mkdir -p "$LOGDIR"
    
    # Запуск демона
    start-stop-daemon -S -b -m -p "$PIDFILE" \
        -x "$BIN" -- daemon -config "$CONFIG"
    
    sleep 1
    
    if pidof "$NAME" > /dev/null; then
        echo "$NAME started"
    else
        echo "Failed to start $NAME"
        return 1
    fi
}

stop() {
    if ! pidof "$NAME" > /dev/null; then
        echo "$NAME is not running"
        return 0
    fi
    
    echo "Stopping $NAME..."
    start-stop-daemon -K -p "$PIDFILE"
    rm -f "$PIDFILE"
    
    sleep 1
    
    if ! pidof "$NAME" > /dev/null; then
        echo "$NAME stopped"
    else
        echo "Failed to stop $NAME"
        return 1
    fi
}

restart() {
    stop
    sleep 1
    start
}

status() {
    if pidof "$NAME" > /dev/null; then
        PID=$(pidof "$NAME")
        echo "$NAME is running (PID: $PID)"
        return 0
    else
        echo "$NAME is stopped"
        return 1
    fi
}

case "$1" in
    start)   start ;;
    stop)    stop ;;
    restart) restart ;;
    status)  status ;;
    *)       echo "Usage: $0 {start|stop|restart|status}" ;;
esac

exit 0
EOF
    
    chmod +x "$SERVICE_FILE"
    
    log_success "Сервис зарегистрирован"
}

# =============================================================================
# ЗАПУСК СЕРВИСА
# =============================================================================

start_service() {
    log_step "Запуск сервиса"
    
    "$SERVICE_FILE" start
    
    sleep 2
    
    # Health check
    if pidof routeguard > /dev/null; then
        log_success "Сервис запущен"
    else
        log_error "Не удалось запустить сервис"
        log_info "Проверьте логи: $LOG_DIR/routeguard.log"
        exit 1
    fi
}

# =============================================================================
# ВЫВОД ИНФОРМАЦИИ
# =============================================================================

print_summary() {
    LOCAL_IP=$(cat "$INSTALL_DIR/.local_ip" 2>/dev/null || echo "ROUTER_IP")
    API_TOKEN=$(cat "$INSTALL_DIR/.api_token" 2>/dev/null || echo "unknown")
    
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   RouteGuard успешно установлен!                  ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "  🌐 Web UI:  http://${LOCAL_IP}:8080"
    echo "  🔑 Токен:   ${API_TOKEN}"
    echo ""
    echo "  📁 Директории:"
    echo "     Конфигурация: $INSTALL_DIR"
    echo "     Логи: $LOG_DIR"
    echo "     Данные: $DATA_DIR"
    echo ""
    echo "  🎛️ Управление:"
    echo "     $SERVICE_FILE start|stop|restart|status"
    echo "     routeguard status|update|backup|restore"
    echo ""
    echo "  📚 Документация:"
    echo "     https://github.com/${REPO}"
    echo ""
    echo "  ⚠️  Сохраните токен доступа в безопасном месте!"
    echo ""
}

# =============================================================================
# ОСНОВНАЯ ФУНКЦИЯ
# =============================================================================

main() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   RouteGuard Installer v${VERSION}                 ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    check_prerequisites
    download_binaries
    install_dependencies
    create_directories
    generate_config
    register_service
    start_service
    print_summary
}

# Запуск
main "$@"
