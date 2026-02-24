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
PORT=${RG_PORT:-8080}
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
    cat > "$INSTALL_DIR/config.json" << EOF
{
    "version": "$VERSION",
    "api": {
        "host": "0.0.0.0",
        "port": 8080,
        "token": "$TOKEN",
        "cors": true
    },
    "vpn": {"enabled": true, "core": "sing-box"},
    "routing": {"enabled": true, "mode": "domain"},
    "dns": {"enabled": true, "port": 53, "upstream": "tls://1.1.1.1"},
    "dpi": {"enabled": false},
    "logging": {"level": "info", "file": "/opt/var/log/routeguard/routeguard.log"}
}
EOF
    echo "$TOKEN" > "$INSTALL_DIR/.api_token"
    chmod 600 "$INSTALL_DIR/.api_token"
fi

# Start service
echo "Starting RouteGuard..."
routeguard start

sleep 2

# Summary
TOKEN=$(cat "$INSTALL_DIR/.api_token" 2>/dev/null || echo "unknown")
IP=$(hostname -i 2>/dev/null || echo "192.168.1.1")

echo ""
echo "=== RouteGuard Ready ==="
echo "Web UI: http://$IP:8080"
echo "Token:  $TOKEN"
echo "Manage: routeguard start|stop|status"
echo ""
