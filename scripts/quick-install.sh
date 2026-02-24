#!/bin/sh
# RouteGuard Quick Install Script
# One-line install: curl -sL https://github.com/alexandr-kuz/RouteGuard/releases/download/v0.2.1/quick-install.sh | sh

REPO="alexandr-kuz/RouteGuard"
VERSION="0.2.1"
INSTALL_DIR="/opt/etc/routeguard"
LOG_DIR="/opt/var/log/routeguard"

echo "╔════════════════════════════════════════════════╗"
echo "║     RouteGuard v$VERSION Installer            ║"
echo "╚════════════════════════════════════════════════╝"
echo ""

# Stop existing
killall python3 2>/dev/null
killall sing-box 2>/dev/null

# Полная очистка
rm -rf "$INSTALL_DIR"
rm -f /opt/bin/routeguard

# Создание директорий
mkdir -p "$INSTALL_DIR/frontend"
mkdir -p "$INSTALL_DIR/profiles"
mkdir -p "$INSTALL_DIR/rulesets"
mkdir -p "$INSTALL_DIR/certs"
mkdir -p "$LOG_DIR"

# Download Python server
echo "[1/5] Загрузка сервера..."
curl -sL "https://github.com/$REPO/releases/download/v$VERSION/python-server.zip" -o /tmp/ps.zip
python3 -c "import zipfile; zipfile.ZipFile('/tmp/ps.zip').extractall('$INSTALL_DIR')"
rm -f /tmp/ps.zip

# Download frontend
echo "[2/5] Загрузка интерфейса..."
curl -sL "https://github.com/$REPO/releases/download/v0.2.1/vpn-with-login.zip" -o /tmp/f.zip
python3 -c "import zipfile; zipfile.ZipFile('/tmp/f.zip').extractall('$INSTALL_DIR')"
rm -f /tmp/f.zip

# Install dependencies
echo "[3/5] Установка зависимостей..."
opkg update >/dev/null 2>&1
opkg install sing-box 2>/dev/null && echo "  ✓ sing-box установлен" || echo "  ✗ sing-box недоступен (опционально)"
opkg install byedpi 2>/dev/null && echo "  ✓ byedpi установлен" || echo "  ✗ byedpi недоступен (опционально)"

# Generate config
echo "[4/5] Генерация конфигурации..."
TOKEN=$(python3 -c "import secrets; print(secrets.token_hex(32))")
IP=$(hostname -i 2>/dev/null || echo "192.168.1.1")
PORT=5000

cat > "$INSTALL_DIR/config.json" << EOF
{
    "version": "$VERSION",
    "api": {
        "host": "0.0.0.0",
        "port": $PORT,
        "token": "$TOKEN",
        "cors": true
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
        "port": 5353,
        "upstream": "tls://1.1.1.1",
        "bootstrap": "1.1.1.1",
        "cache_ttl": 300,
        "adblock": {
            "enabled": true,
            "lists": [
                "https://raw.githubusercontent.com/AdguardTeam/AdguardFilters/master/RussianFilter/sections/popups.txt"
            ]
        }
    },
    "dpi": {
        "enabled": false,
        "mode": "auto",
        "bypass_domains": ["youtube.com", "instagram.com"]
    },
    "logging": {
        "level": "info",
        "file": "$LOG_DIR/routeguard.log",
        "max_size_mb": 10,
        "max_backups": 3
    },
    "update": {
        "auto_check": true,
        "check_interval": "24h"
    },
    "security": {
        "rate_limit": 100,
        "session_timeout": "24h"
    }
}
EOF

echo "$TOKEN" > "$INSTALL_DIR/.api_token"
chmod 600 "$INSTALL_DIR/.api_token"
echo "$PORT" > "$INSTALL_DIR/.port"

# Create default VPN profile
cat > "$INSTALL_DIR/profiles/default.json" << EOF
{
    "name": "Default",
    "enabled": false,
    "protocol": "wireguard",
    "config": {}
}
EOF

# Create launcher
echo "[5/5] Регистрация сервиса..."
cat > "/opt/bin/routeguard" << 'LAUNCHER'
#!/bin/sh
CONFIG="/opt/etc/routeguard/config.json"
LOGFILE="/opt/var/log/routeguard/routeguard.log"

if [ -f "$CONFIG" ]; then
    PORT=$(python3 -c "import json; print(json.load(open('$CONFIG')).get('api',{}).get('port',5000))" 2>/dev/null || echo "5000")
else
    PORT=5000
fi

case "$1" in
    start)
        if pgrep -f "python3.*server.py" >/dev/null; then
            echo "RouteGuard уже запущен"
            exit 0
        fi
        echo "Запуск RouteGuard на порту $PORT..."
        python3 /opt/etc/routeguard/server.py > "$LOGFILE" 2>&1 &
        sleep 2
        if pgrep -f "python3.*server.py" >/dev/null; then
            echo "✓ RouteGuard запущен"
        else
            echo "✗ Ошибка запуска. Логи: $LOGFILE"
        fi
        ;;
    stop)
        killall python3 2>/dev/null && echo "✓ Остановлен" || echo "Не запущен"
        ;;
    restart)
        $0 stop; sleep 1; $0 start
        ;;
    status)
        if pgrep -f "python3.*server.py" >/dev/null; then
            echo "✓ Запущен (PID: $(pgrep -f 'python3.*server.py'))"
        else
            echo "✗ Остановлен"
        fi
        ;;
    *)
        echo "Использование: routeguard {start|stop|restart|status}"
        ;;
esac
LAUNCHER
chmod +x "/opt/bin/routeguard"

# Start service
echo ""
echo "Запуск RouteGuard..."
routeguard start

sleep 2

# Summary
TOKEN=$(cat "$INSTALL_DIR/.api_token" 2>/dev/null || echo "unknown")

echo ""
echo "╔════════════════════════════════════════════════╗"
echo "║       RouteGuard готов к работе!              ║"
echo "╚════════════════════════════════════════════════╝"
echo ""
echo "  🌐 Web UI:  http://$IP:$PORT/"
echo "  🔑 Токен:   $TOKEN"
echo ""
echo "  📁 Директории:"
echo "     Конфигурация: $INSTALL_DIR"
echo "     Логи: $LOG_DIR"
echo ""
echo "  🎮 Управление:"
echo "     routeguard start|stop|restart|status"
echo ""
echo "  📚 Документация:"
echo "     https://github.com/$REPO"
echo ""
echo "  ⚠️  Сохраните токен в безопасном месте!"
echo ""
