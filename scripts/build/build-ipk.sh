#!/bin/bash
# RouteGuard IPK Package Builder
# Создаёт OPKG-пакеты для Entware (MIPS, ARM, AMD64)

set -e

# =============================================================================
# КОНФИГУРАЦИЯ
# =============================================================================

VERSION="${1:-0.1.0}"
DIST_DIR="dist"
SCRIPTS_DIR="scripts"
BUILD_DIR="build"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# =============================================================================
# ФУНКЦИИ
# =============================================================================

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# =============================================================================
# ПОДГОТОВКА
# =============================================================================

prepare() {
    log_info "Подготовка директорий..."
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    mkdir -p "$DIST_DIR/packages"
    log_success "Директории готовы"
}

# =============================================================================
# СОЗДАНИЕ ПАКЕТА
# =============================================================================

create_package() {
    local ARCH="$1"
    local ARCH_DIR="$2"
    
    log_info "Создание пакета для $ARCH..."
    
    # Проверка наличия бинарника
    if [ ! -f "$DIST_DIR/$ARCH_DIR/routeguard" ]; then
        log_warn "Бинарник для $ARCH не найден, пропускаем"
        return 0
    fi
    
    # Структура пакета
    local PKG_DIR="$BUILD_DIR/routeguard-$ARCH"
    mkdir -p "$PKG_DIR/CONTROL"
    mkdir -p "$PKG_DIR/opt/bin"
    mkdir -p "$PKG_DIR/opt/etc/routeguard"
    mkdir -p "$PKG_DIR/opt/var/log/routeguard"
    mkdir -p "$PKG_DIR/opt/var/lib/routeguard"
    
    # Копирование файлов
    cp "$DIST_DIR/$ARCH_DIR/routeguard" "$PKG_DIR/opt/bin/"
    chmod 755 "$PKG_DIR/opt/bin/routeguard"
    
    # Копирование frontend если есть
    if [ -d "$DIST_DIR/frontend" ]; then
        mkdir -p "$PKG_DIR/opt/share/routeguard/ui"
        cp -r "$DIST_DIR/frontend/"* "$PKG_DIR/opt/share/routeguard/ui/"
    fi
    
    # Копирование скриптов установки
    if [ -f "$SCRIPTS_DIR/install.sh" ]; then
        cp "$SCRIPTS_DIR/install.sh" "$PKG_DIR/opt/etc/routeguard/"
    fi
    
    if [ -f "$SCRIPTS_DIR/uninstall.sh" ]; then
        cp "$SCRIPTS_DIR/uninstall.sh" "$PKG_DIR/opt/etc/routeguard/"
    fi
    
    # Control file
    cat > "$PKG_DIR/CONTROL/control" << EOF
Package: routeguard
Version: $VERSION
Architecture: $ARCH
Maintainer: RouteGuard Team
Section: net
Priority: optional
Depends: curl, openssl
Description: RouteGuard - VPN-платформа для Entware
 Универсальная VPN-платформа для роутеров с Entware.
 Поддерживает sing-box, WireGuard, OpenVPN и другие протоколы.
 Включает DNS-over-HTTPS, обход DPI и управление маршрутизацией.
Homepage: https://github.com/alexandr-kuz/RouteGuard
EOF

    # Post-install script
    cat > "$PKG_DIR/CONTROL/postinst" << 'POSTINST'
#!/bin/sh
echo "RouteGuard установлен!"
echo ""
echo "Запустите: /opt/etc/routeguard/install.sh"
echo "Или вручную создайте конфигурацию в /opt/etc/routeguard/"
POSTINST
    chmod 755 "$PKG_DIR/CONTROL/postinst"
    
    # Pre-remove script
    cat > "$PKG_DIR/CONTROL/prerm" << 'PRERM'
#!/bin/sh
echo "Остановка RouteGuard..."
killall routeguard 2>/dev/null || true
PRERM
    chmod 755 "$PKG_DIR/CONTROL/prerm"
    
    log_success "Структура пакета для $ARCH создана"
}

# =============================================================================
# СБОРКА IPK
# =============================================================================

build_ipk() {
    local ARCH="$1"
    local PKG_DIR="$BUILD_DIR/routeguard-$ARCH"
    local OUTPUT="$DIST_DIR/packages/routeguard_${VERSION}_${ARCH}.ipk"
    
    if [ ! -d "$PKG_DIR" ]; then
        return 0
    fi
    
    log_info "Сборка IPK для $ARCH..."
    
    # Создание control.tar.gz
    cd "$PKG_DIR"
    tar -czf "$BUILD_DIR/control.tar.gz" -C CONTROL .
    
    # Создание data.tar.gz
    tar -czf "$BUILD_DIR/data.tar.gz" \
        --exclude='./CONTROL' \
        .
    
    # Создание debian-binary
    echo "2.0" > "$BUILD_DIR/debian-binary"
    
    # Создание IPK (ar архив)
    cd "$BUILD_DIR"
    ar -rc "$OUTPUT" debian-binary control.tar.gz data.tar.gz
    
    log_success "Пакет создан: $OUTPUT"
}

# =============================================================================
# ОСНОВНОЙ ПРОЦЕСС
# =============================================================================

main() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   RouteGuard IPK Builder v${VERSION}              ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Проверка наличия ar (часть binutils)
    if ! command -v ar >/dev/null 2>&1; then
        log_error "ar не найден. Установите binutils."
        exit 1
    fi
    
    prepare
    
    # Создание пакетов для каждой архитектуры
    create_package "mips" "mips"
    create_package "arm" "arm"
    create_package "amd64" "amd64"
    
    # Сборка IPK
    build_ipk "mips"
    build_ipk "arm"
    build_ipk "amd64"
    
    # Очистка
    rm -rf "$BUILD_DIR"
    
    echo ""
    log_success "Готово! Пакеты в $DIST_DIR/packages/"
    ls -la "$DIST_DIR/packages/" 2>/dev/null || echo "Нет созданных пакетов"
}

main "$@"
