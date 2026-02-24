#!/bin/sh
# RouteGuard Uninstaller
# Удаление: curl -sL https://github.com/alexandr-kuz/RouteGuard/releases/latest/download/uninstall.sh | sh
#
# Документация: https://github.com/alexandr-kuz/RouteGuard

set -e

# =============================================================================
# КОНФИГУРАЦИЯ
# =============================================================================

INSTALL_DIR="/opt/etc/routeguard"
BIN_DIR="/opt/bin"
LOG_DIR="/opt/var/log/routeguard"
DATA_DIR="/opt/var/lib/routeguard"
SERVICE_FILE="/opt/etc/init.d/S50rguard"
CONFIG_FILE="$INSTALL_DIR/config.json"
PIDFILE="/var/run/routeguard.pid"

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
# ПРОВЕРКА ПРАВ ДОСТУПА
# =============================================================================

check_root() {
    if [ "$(id -u)" != "0" ]; then
        log_error "Требуется запуск от root"
        exit 1
    fi
}

# =============================================================================
# ОСНОВНЫЕ ФУНКЦИИ
# =============================================================================

stop_service() {
    log_step "Остановка сервиса"
    
    if [ -f "$SERVICE_FILE" ]; then
        if pidof routeguard > /dev/null; then
            $SERVICE_FILE stop 2>/dev/null || true
            sleep 2
        fi
        log_success "Сервис остановлен"
    else
        log_warn "Файл сервиса не найден"
    fi
    
    # Принудительная остановка если процесс ещё жив
    if pidof routeguard > /dev/null; then
        log_warn "Принудительная остановка процесса"
        killall routeguard 2>/dev/null || true
        sleep 1
    fi
}

remove_service() {
    log_step "Удаление сервиса"
    
    if [ -f "$SERVICE_FILE" ]; then
        rm -f "$SERVICE_FILE"
        log_success "Файл сервиса удалён"
    else
        log_warn "Файл сервиса не найден"
    fi
    
    # Удаление ссылок на автозагрузку
    if [ -L "/opt/etc/rc.d/S50rguard" ]; then
        rm -f "/opt/etc/rc.d/S50rguard"
        log_success "Автозагрузка удалена"
    fi
}

remove_binary() {
    log_step "Удаление бинарника"
    
    if [ -f "$BIN_DIR/routeguard" ]; then
        rm -f "$BIN_DIR/routeguard"
        log_success "Бинарник удалён"
    else
        log_warn "Бинарник не найден"
    fi
}

remove_config() {
    log_step "Удаление конфигурации"
    
    if [ -d "$INSTALL_DIR" ]; then
        rm -rf "$INSTALL_DIR"
        log_success "Конфигурация удалена"
    else
        log_warn "Директория конфигурации не найдена"
    fi
    
    if [ -f "$CONFIG_FILE" ]; then
        rm -f "$CONFIG_FILE"
        log_success "Конфигурационный файл удалён"
    fi
}

remove_logs() {
    log_step "Удаление логов"
    
    if [ -d "$LOG_DIR" ]; then
        rm -rf "$LOG_DIR"
        log_success "Логи удалены"
    else
        log_warn "Директория логов не найдена"
    fi
}

remove_data() {
    log_step "Удаление данных"
    
    if [ -d "$DATA_DIR" ]; then
        rm -rf "$DATA_DIR"
        log_success "Данные удалены"
    else
        log_warn "Директория данных не найдена"
    fi
}

remove_pidfile() {
    log_step "Удаление PID файла"
    
    if [ -f "$PIDFILE" ]; then
        rm -f "$PIDFILE"
        log_success "PID файл удалён"
    fi
}

cleanup_empty_dirs() {
    log_step "Очистка пустых директорий"
    
    # Попытка удалить пустые директории (не критично если не получится)
    rmdir "$INSTALL_DIR" 2>/dev/null || true
    rmdir "$LOG_DIR" 2>/dev/null || true
    rmdir "$DATA_DIR" 2>/dev/null || true
}

# =============================================================================
# ОПЦИОНАЛЬНОЕ УДАЛЕНИЕ ЗАВИСИМОСТЕЙ
# =============================================================================

remove_dependencies() {
    log_step "Удаление зависимостей (опционально)"
    
    echo ""
    echo "Удалить зависимости? (sing-box, smartdns, byedpi)"
    echo "  y - да, удалить"
    echo "  n - нет, оставить"
    echo ""
    read -p "Ваш выбор [y/N]: " choice
    
    case "$choice" in
        y|Y)
            log_info "Удаление sing-box..."
            opkg remove sing-box 2>/dev/null || log_warn "sing-box не установлен"
            
            log_info "Удаление smartdns..."
            opkg remove smartdns 2>/dev/null || log_warn "smartdns не установлен"
            
            log_info "Удаление byedpi..."
            opkg remove byedpi 2>/dev/null || log_warn "byedpi не установлен"
            
            log_success "Зависимости удалены"
            ;;
        *)
            log_info "Зависимости сохранены"
            ;;
    esac
}

# =============================================================================
# СОЗДАНИЕ ОТЧЁТА
# =============================================================================

create_report() {
    echo ""
    echo "╔════════════════════════════════════════════════════╗"
    echo "║   RouteGuard успешно удалён!                       ║"
    echo "╚════════════════════════════════════════════════════╝"
    echo ""
    echo "Удалено:"
    echo "  ✓ Сервис и автозагрузка"
    echo "  ✓ Бинарник"
    echo "  ✓ Конфигурация"
    echo "  ✓ Логи"
    echo "  ✓ Данные"
    echo ""
    echo "Сохранено:"
    echo "  • Зависимости (sing-box, smartdns, byedpi)"
    echo ""
    echo "Для полной очистки можно удалить вручную:"
    echo "  rm -rf /opt/etc/routeguard"
    echo "  rm -rf /opt/var/log/routeguard"
    echo "  rm -rf /opt/var/lib/routeguard"
    echo ""
}

# =============================================================================
# ОСНОВНОЙ СЦЕНАРИЙ
# =============================================================================

main() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   RouteGuard Uninstaller                        ║${NC}"
    echo -e "${BLUE}║   Удаление VPN-платформы с роутера              ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Проверка прав
    check_root
    
    # Проверка установки
    if [ ! -f "$BIN_DIR/routeguard" ] && [ ! -f "$SERVICE_FILE" ]; then
        log_error "RouteGuard не найден. Удаление не требуется."
        exit 1
    fi
    
    # Подтверждение
    echo "ВНИМАНИЕ: Будут удалены все данные RouteGuard!"
    echo ""
    read -p "Продолжить удаление? [y/N]: " confirm
    
    case "$confirm" in
        y|Y)
            # Выполнение удаления
            stop_service
            remove_service
            remove_binary
            remove_config
            remove_logs
            remove_data
            remove_pidfile
            cleanup_empty_dirs
            
            create_report
            ;;
        *)
            log_info "Удаление отменено"
            exit 0
            ;;
    esac
}

# Запуск
main "$@"
