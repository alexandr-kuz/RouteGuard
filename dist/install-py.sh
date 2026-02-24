#!/bin/sh
# RouteGuard Python Installer
# Для роутеров с Python 3

REPO="alexandr-kuz/RouteGuard"
VERSION="0.2.1"

INSTALL_DIR="/opt/etc/routeguard"
BIN_DIR="/opt/bin"
LOG_DIR="/opt/var/log/routeguard"

echo "━━━ Установка RouteGuard (Python версия) ━━━"

# Проверка Python
if ! command -v python3 >/dev/null 2>&1; then
    echo "[ERROR] Python 3 не найден!"
    echo "Установите: opkg install python3"
    exit 1
fi

echo "[OK] Python 3 найден: $(python3 --version)"

# Создание директорий
mkdir -p "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR/profiles"
mkdir -p "$INSTALL_DIR/rulesets"
mkdir -p "$INSTALL_DIR/frontend"
mkdir -p "$LOG_DIR"

echo "[OK] Директории созданы"

# Загрузка сервера
echo "[INFO] Загрузка сервера..."
curl -sL "https://raw.githubusercontent.com/$REPO/main/backend/server.py" -o "$INSTALL_DIR/server.py"

if [ ! -f "$INSTALL_DIR/server.py" ]; then
    echo "[ERROR] Не удалось загрузить server.py"
    exit 1
fi

chmod +x "$INSTALL_DIR/server.py"
echo "[OK] Сервер загружен"

# Загрузка фронтенда
echo "[INFO] Загрузка фронтенда..."
curl -sL "https://github.com/$REPO/releases/download/v$VERSION/frontend.zip" -o "/tmp/frontend.zip"

if [ -f "/tmp/frontend.zip" ]; then
    # Распаковка (если есть unzip)
    if command -v unzip >/dev/null 2>&1; then
        unzip -q /tmp/frontend.zip -d "$INSTALL_DIR/frontend"
    else
        # Если нет unzip, оставляем zip для ручной распаковки
        echo "[WARN] unzip не найден, фронтенд в /tmp/frontend.zip"
    fi
    rm -f /tmp/frontend.zip
fi

# Генерация токена если нет
CONFIG_FILE="$INSTALL_DIR/config.json"
if [ ! -f "$CONFIG_FILE" ]; then
    API_TOKEN=$(python3 -c "import secrets; print(secrets.token_hex(32))")
    LOCAL_IP=$(hostname -i 2>/dev/null || echo "192.168.1.1")
    
    cat > "$CONFIG_FILE" << EOF
{
    "version": "$VERSION",
    "api": {
        "host": "0.0.0.0",
        "port": 8080,
        "token": "$API_TOKEN",
        "cors": true
    },
    "vpn": {
        "enabled": true,
        "core": "sing-box",
        "config_dir": "$INSTALL_DIR/profiles"
    },
    "routing": {
        "enabled": true,
        "mode": "domain",
        "default_route": "direct"
    },
    "dns": {
        "enabled": true,
        "port": 53,
        "upstream": "tls://1.1.1.1"
    },
    "dpi": {
        "enabled": false
    },
    "logging": {
        "level": "info",
        "file": "$LOG_DIR/routeguard.log"
    }
}
EOF
    echo "[OK] Конфигурация создана"
fi

# Создание скрипта запуска
cat > "$BIN_DIR/routeguard" << 'EOF'
#!/bin/sh
# RouteGuard Launcher
CONFIG="/opt/etc/routeguard/config.json"
LOG="/opt/var/log/routeguard/routeguard.log"
PIDFILE="/var/run/routeguard.pid"

case "$1" in
    start)
        if [ -f "$PIDFILE" ] && kill -0 $(cat "$PIDFILE") 2>/dev/null; then
            echo "routeguard уже запущен"
            exit 0
        fi
        echo "Запуск routeguard..."
        nohup python3 /opt/etc/routeguard/server.py > "$LOG" 2>&1 &
        echo $! > "$PIDFILE"
        sleep 2
        if pidof python3 >/dev/null; then
            echo "routeguard запущен (PID: $(cat $PIDFILE))"
        else
            echo "Ошибка запуска routeguard"
            exit 1
        fi
        ;;
    stop)
        if [ -f "$PIDFILE" ]; then
            kill $(cat "$PIDFILE") 2>/dev/null
            rm -f "$PIDFILE"
            echo "routeguard остановлен"
        else
            echo "routeguard не запущен"
        fi
        ;;
    restart)
        $0 stop
        sleep 1
        $0 start
        ;;
    status)
        if [ -f "$PIDFILE" ] && kill -0 $(cat "$PIDFILE") 2>/dev/null; then
            echo "routeguard запущен (PID: $(cat $PIDFILE))"
        else
            echo "routeguard остановлен"
        fi
        ;;
    *)
        echo "Использование: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac
EOF

chmod +x "$BIN_DIR/routeguard"
echo "[OK] Скрипт запуска создан"

# Сохранение токена
API_TOKEN=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['api']['token'])" 2>/dev/null || echo "unknown")
echo "$API_TOKEN" > "$INSTALL_DIR/.api_token"
chmod 600 "$INSTALL_DIR/.api_token"

# Запуск сервиса
echo ""
echo "[INFO] Запуск сервиса..."
"$BIN_DIR/routeguard" start

sleep 2

# Вывод информации
echo ""
echo "╔════════════════════════════════════════════════════╗"
echo "║   RouteGuard успешно установлен!                  ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""
echo "  🌐 Web UI:  http://$(hostname -i 2>/dev/null || echo 'ROUTER_IP'):8080"
echo "  🔑 Токен:   $API_TOKEN"
echo ""
echo "  Управление:"
echo "    routeguard start|stop|restart|status"
echo ""
echo "  Логи:"
echo "    $LOG"
echo ""
echo "  ⚠️  Сохраните токен в безопасном месте!"
echo ""
