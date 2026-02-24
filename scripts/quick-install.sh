#!/bin/sh
# RouteGuard Quick Install Script
# One-line install: curl -sL https://github.com/alexandr-kuz/RouteGuard/releases/download/v0.2.1/quick-install.sh | sh

REPO="alexandr-kuz/RouteGuard"
VERSION="0.2.1"
INSTALL_DIR="/opt/etc/routeguard"
LOG_DIR="/opt/var/log/routeguard"

echo "=== RouteGuard Installer ==="

# Stop existing
killall python3 2>/dev/null

# Полная очистка и создание директорий
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR/frontend"
mkdir -p "$INSTALL_DIR/profiles"
mkdir -p "$INSTALL_DIR/rulesets"
mkdir -p "$LOG_DIR"

# Download Python server
echo "Downloading server..."
curl -sL "https://github.com/$REPO/releases/download/v$VERSION/python-server.zip" -o /tmp/ps.zip
python3 -c "import zipfile; zipfile.ZipFile('/tmp/ps.zip').extractall('$INSTALL_DIR')"
rm -f /tmp/ps.zip

# Download frontend
echo "Downloading frontend..."
curl -sL "https://github.com/$REPO/releases/download/v$VERSION/frontend.zip" -o /tmp/f.zip
python3 -c "import zipfile; zipfile.ZipFile('/tmp/f.zip').extractall('$INSTALL_DIR/')"
rm -f /tmp/f.zip

# Create launcher script
cat > "/opt/bin/routeguard" << 'LAUNCHER'
#!/bin/sh
CONFIG="/opt/etc/routeguard/config.json"
# Порт из конфига или переменной окружения
if [ -f "$CONFIG" ]; then
    PORT=$(python3 -c "import json; print(json.load(open('$CONFIG')).get('api',{}).get('port',8080))" 2>/dev/null || echo "${RG_PORT:-8080}")
else
    PORT=${RG_PORT:-8080}
fi

case "$1" in
    start)
        echo "Starting RouteGuard on port $PORT..."
        RG_PORT=$PORT nohup python3 /opt/etc/routeguard/server.py > /opt/var/log/routeguard/routeguard.log 2>&1 &
        echo "Started (PID: $!)"
        ;;
    stop)
        killall python3 2>/dev/null && echo "Stopped" || echo "Not running"
        ;;
    restart)
        $0 stop; sleep 1; $0 start
        ;;
    status)
        pgrep -f "python3.*server.py" && echo "Running" || echo "Stopped"
        ;;
    *)
        echo "Usage: routeguard {start|stop|restart|status}"
        ;;
esac
LAUNCHER
chmod +x "/opt/bin/routeguard"

# Generate config if needed
if [ ! -f "$INSTALL_DIR/config.json" ]; then
    TOKEN=$(python3 -c "import secrets; print(secrets.token_hex(32))")
    IP=$(hostname -i 2>/dev/null || echo "192.168.1.1")
    
    # Проверка порта 8080 - если занят, использовать 80
    if netstat -tlnp 2>/dev/null | grep -q ":8080 "; then
        PORT=80
        echo "[INFO] Port 8080 busy, using port 80"
    else
        PORT=8080
    fi
    
    cat > "$INSTALL_DIR/config.json" << EOF
{
    "version": "$VERSION",
    "api": {
        "host": "0.0.0.0",
        "port": $PORT,
        "token": "$TOKEN",
        "cors": true
    },
    "vpn": {"enabled": true, "core": "sing-box"},
    "routing": {"enabled": true, "mode": "domain"},
    "dns": {"enabled": true, "port": 53, "upstream": "tls://1.1.1.1"},
    "dpi": {"enabled": false},
    "logging": {"level": "info", "file": "$LOG_DIR/routeguard.log"}
}
EOF
    echo "$TOKEN" > "$INSTALL_DIR/.api_token"
    chmod 600 "$INSTALL_DIR/.api_token"
    echo "$PORT" > "$INSTALL_DIR/.port"
fi

# Start service
echo "Starting RouteGuard..."
routeguard start

sleep 2

# Summary
TOKEN=$(cat "$INSTALL_DIR/.api_token" 2>/dev/null || echo "unknown")
PORT=$(cat "$INSTALL_DIR/.port" 2>/dev/null || echo "8080")
IP=$(hostname -i 2>/dev/null || echo "192.168.1.1")

# Формирование URL
if [ "$PORT" = "80" ]; then
    URL="http://$IP/"
else
    URL="http://$IP:$PORT/"
fi

echo ""
echo "=== RouteGuard Ready ==="
echo "Web UI:  $URL"
echo "Token:   $TOKEN"
echo "Manage:  routeguard start|stop|status"
echo ""
