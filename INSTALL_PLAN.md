# 📋 RouteGuard — Полный план установки и настройки

> **Статус проекта:** Разработка (v0.1.0)
>
> Этот документ содержит пошаговую инструкцию по сборке, установке и настройке RouteGuard на роутере Keenetic с Entware.

---

## 📖 Оглавление

1. [Подготовка окружения](#1-подготовка-окружения)
2. [Быстрый старт](#2-быстрый-старт)
3. [Сборка проекта](#3-сборка-проекта)
4. [Подготовка роутера](#4-подготовка-роутера)
5. [Установка на роутер](#5-установка-на-роутер)
6. [Первичная настройка](#6-первичная-настройка)
7. [Настройка VPN](#7-настройка-vpn)
8. [Настройка маршрутизации](#8-настройка-маршрутизации)
9. [Настройка DNS](#9-настройка-dns)
10. [Настройка DPI обхода](#10-настройка-dpi-обхода)
11. [Финальная проверка](#11-финальная-проверка)
12. [Решение проблем](#12-решение-проблем)

---

## 1. Подготовка окружения

### 1.1. Минимальные требования

| Компонент | Версия | Примечание |
|-----------|--------|------------|
| Go | 1.21+ | Для сборки backend |
| Node.js | 18+ | Для сборки frontend |
| npm | 9+ | Менеджер пакетов Node.js |
| Git | 2+ | Для клонирования репозитория |

### 1.2. Установка зависимостей (Windows)

```powershell
# Установите через winget
winget install GoLang.Go
winget install OpenJS.NodeJS.LTS
winget install Git.Git
```

Или скачайте с официальных сайтов:
- **Go:** https://go.dev/dl/
- **Node.js:** https://nodejs.org/
- **Git:** https://git-scm.com/

### 1.3. Проверка установки

```powershell
go version      # ожидается: go version go1.21+
node --version  # ожидается: v18+
npm --version   # ожидается: 9+
git --version   # ожидается: git version 2+
```

### 1.4. Клонируйте репозиторий

```powershell
# Клонируйте репозиторий
git clone https://github.com/alexandr-kuz/RouteGuard.git
cd RouteGuard
```

---

## 2. Быстрый старт

### 2.1. Автоматическая сборка (рекомендуется)

```powershell
# Установите зависимости и соберите проект
make build

# Или вручную:
# Backend
cd backend
go mod download
go build -o ../dist/routeguard.exe ./main.go

# Frontend
cd ../frontend
npm install
npm run build
```

### 2.2. Локальный запуск для тестирования

```powershell
# Создайте тестовый конфиг (см. раздел 6)
# Запустите сервер
.\dist\routeguard.exe --config config.json

# Проверьте работу
curl http://localhost:8080/health
```

---

## 3. Сборка проекта

### 3.1. Сборка Backend (Go)

```powershell
cd backend

# Загрузка зависимостей
go mod download

# Сборка для Windows (локальное тестирование)
go build -o ../dist/routeguard.exe ./main.go

# Сборка для роутера (Linux)
# Для MIPS (Keenetic Start, Lite, Extra, Omni):
CGO_ENABLED=0 GOOS=linux GOARCH=mips \
    go build -ldflags="-s -w -extldflags '-static'" -trimpath \
    -o ../dist/routeguard-mips ./main.go

# Для ARM (Keenetic Giga, Ultra, Pro):
CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=7 \
    go build -ldflags="-s -w -extldflags '-static'" -trimpath \
    -o ../dist/routeguard-arm ./main.go

# Для x86_64 (Keenetic на Intel):
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags="-s -w -extldflags '-static'" -trimpath \
    -o ../dist/routeguard-amd64 ./main.go
```

### 3.2. Сборка Frontend (Vue 3)

```powershell
cd frontend

# Установка зависимостей
npm install

# Сборка для продакшена
npm run build

# Файлы появятся в frontend/dist/
```

### 3.3. Проверка результатов

```powershell
# Проверка backend
dir dist
# Ожидается:
# - routeguard.exe (Windows)
# - routeguard-mips (Linux MIPS)
# - routeguard-arm (Linux ARM)
# - routeguard-amd64 (Linux x86_64)

# Проверка frontend
dir frontend\dist
# Ожидается:
# - index.html
# - assets/
```

---

## 4. Подготовка роутера

### 4.1. Проверка требований

#### Подключитесь к роутеру по SSH

```powershell
ssh admin@192.168.1.1
# Пароль по умолчанию: admin
```

#### Проверьте Entware

```bash
opkg --version
# Если не найден — установите: https://kb.keenetic.ru/hc/ru/articles/360000202345
```

#### Проверьте архитектуру

```bash
uname -m
# mips, mipsel — MIPS
# armv7l, armv6l — ARM  
# x86_64 — Intel
```

#### Проверьте ресурсы

```bash
free -m          # Свободная RAM (требуется ≥50 MB)
df -h /opt       # Место на /opt (требуется ≥100 MB)
```

### 4.2. Установка зависимостей

```bash
# Обновление пакетов
opkg update

# Базовые утилиты
opkg install curl wget openssl ca-certificates

# sing-box (VPN-ядро)
opkg install sing-box

# smartdns (DNS-сервер, опционально)
opkg install smartdns

# ByeDPI (обход DPI, опционально)
opkg install byedpi
```

---

## 5. Установка на роутер

### 5.1. Копирование файлов

#### Через WinSCP (рекомендуется)

1. Скачайте WinSCP: https://winscp.net/
2. Подключитесь к `192.168.1.1` (логин: `admin`)
3. Перетащите:
   - `dist/routeguard-<arch>` → `/tmp/routeguard`
   - `config.json` → `/tmp/config.json`

#### Через SCP

```powershell
# Для MIPS
scp dist/routeguard-mips admin@192.168.1.1:/tmp/routeguard
scp config.json admin@192.168.1.1:/tmp/config.json
```

### 5.2. Установка

```bash
# Подключитесь по SSH
ssh admin@192.168.1.1

# Создание директорий
mkdir -p /opt/etc/routeguard/{profiles,rulesets,certs}
mkdir -p /opt/var/log/routeguard
mkdir -p /opt/var/lib/routeguard/{geoip,geosite,backups}

# Копирование бинарника
cp /tmp/routeguard /opt/bin/routeguard
chmod +x /opt/bin/routeguard

# Генерация API токена
API_TOKEN=$(openssl rand -hex 32)
echo "$API_TOKEN" > /opt/etc/routeguard/.api_token
chmod 600 /opt/etc/routeguard/.api_token

# Настройка конфига
cp /tmp/config.json /opt/etc/routeguard/config.json
sed -i "s/test-token-change-in-production-abc123xyz789/$API_TOKEN/" /opt/etc/routeguard/config.json
```

### 5.3. Создание сервиса

```bash
cat > /opt/etc/init.d/S50rguard << 'EOF'
#!/bin/sh
NAME="routeguard"
BIN="/opt/bin/routeguard"
CONFIG="/opt/etc/routeguard/config.json"
PIDFILE="/var/run/$NAME.pid"

start() {
    echo "Starting $NAME..."
    start-stop-daemon -S -b -m -p $PIDFILE -x $BIN -- -config $CONFIG
}

stop() {
    echo "Stopping $NAME..."
    start-stop-daemon -K -p $PIDFILE
    rm -f $PIDFILE
}

restart() {
    stop
    sleep 1
    start
}

case "$1" in
    start) start ;;
    stop) stop ;;
    restart) restart ;;
    status)
        if pidof $NAME > /dev/null; then
            echo "$NAME is running"
        else
            echo "$NAME is stopped"
        fi
        ;;
    *) echo "Usage: $0 {start|stop|restart|status}" ;;
esac
EOF

chmod +x /opt/etc/init.d/S50rguard
```

### 5.4. Запуск сервиса

```bash
# Запуск
/opt/etc/init.d/S50rguard start

# Проверка статуса
/opt/etc/init.d/S50rguard status

# Автозагрузка при старте
ln -s /opt/etc/init.d/S50rguard /opt/etc/rc.d/S50rguard
```

---

## 6. Первичная настройка

### 6.1. Конфигурационный файл

Создайте `config.json` в `/opt/etc/routeguard/`:

```json
{
    "version": "0.1.0",
    "installed_at": "2026-02-23T00:00:00Z",
    "api": {
        "host": "0.0.0.0",
        "port": 8080,
        "token": "<ВАШ_API_ТОКЕН>",
        "cors": true,
        "allowed_origins": ["*"]
    },
    "vpn": {
        "enabled": true,
        "core": "sing-box",
        "config_dir": "/opt/etc/routeguard/profiles",
        "auto_connect": false
    },
    "routing": {
        "enabled": true,
        "mode": "domain",
        "default_route": "direct",
        "rulesets_dir": "/opt/etc/routeguard/rulesets"
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
        "file": "/opt/var/log/routeguard/routeguard.log",
        "max_size_mb": 10,
        "max_backups": 3
    },
    "update": {
        "auto_check": false,
        "check_interval": "24h",
        "auto_install": false,
        "install_window": "03:00-05:00"
    },
    "security": {
        "rate_limit": 100,
        "session_timeout": "24h"
    }
}
```

### 6.2. Получение данных для входа

```bash
# API токен
cat /opt/etc/routeguard/.api_token

# IP роутера
hostname -I | awk '{print $1}'
```

**Запишите:**
- **Web UI URL:** `http://<IP-роутера>:8080`
- **API Токен:** `<ваш-токен>`

### 6.3. Первый вход

1. Откройте браузер
2. Перейдите по адресу: `http://192.168.1.1:8080`
3. Введите API токен в заголовке `X-API-Token`

---

## 7. Настройка VPN

### 7.1. API endpoints

```bash
# Получить список профилей
curl -H "X-API-Token: <токен>" \
    http://192.168.1.1:8080/api/v1/vpn/profiles

# Добавить профиль
curl -X POST -H "X-API-Token: <токен>" \
    -H "Content-Type: application/json" \
    -d '{"name":"MyVPN","type":"wireguard","config":"..."}' \
    http://192.168.1.1:8080/api/v1/vpn/profiles

# Подключиться
curl -X POST -H "X-API-Token: <токен>" \
    http://192.168.1.1:8080/api/v1/vpn/profiles/<id>/connect

# Статус
curl -H "X-API-Token: <токен>" \
    http://192.168.1.1:8080/api/v1/vpn/status
```

### 7.2. Проверка подключения

```bash
# Внешний IP до подключения
curl ifconfig.me

# После подключения должен измениться
curl --proxy socks5h://localhost:1080 ifconfig.me
```

---

## 8. Настройка маршрутизации

### 8.1. API endpoints

```bash
# Получить правила
curl -H "X-API-Token: <токен>" \
    http://192.168.1.1:8080/api/v1/routing/rules

# Добавить правило
curl -X POST -H "X-API-Token: <токен>" \
    -H "Content-Type: application/json" \
    -d '{
        "type": "domain",
        "domains": [".ru"],
        "action": "direct",
        "priority": 100,
        "enabled": true
    }' \
    http://192.168.1.1:8080/api/v1/routing/rules

# Обновить GeoIP
curl -X POST -H "X-API-Token: <токен>" \
    http://192.168.1.1:8080/api/v1/routing/geoip/update
```

### 8.2. Примеры правил

| Тип | Домен/IP | Действие | Приоритет |
|-----|----------|----------|-----------|
| Domain | .ru | Direct | 100 |
| Domain | youtube.com, instagram.com | Proxy | 200 |
| Domain | .cn | Proxy | 100 |

---

## 9. Настройка DNS

### 9.1. API endpoints

```bash
# Получить настройки
curl -H "X-API-Token: <токен>" \
    http://192.168.1.1:8080/api/v1/dns/settings

# Обновить настройки
curl -X PUT -H "X-API-Token: <токен>" \
    -H "Content-Type: application/json" \
    -d '{
        "upstream": "tls://1.1.1.1",
        "bootstrap": "1.1.1.1",
        "cache_ttl": 300
    }' \
    http://192.168.1.1:8080/api/v1/dns/settings

# Очистить кэш
curl -X POST -H "X-API-Token: <токен>" \
    http://192.168.1.1:8080/api/v1/dns/cache/clear
```

### 9.2. Блокировка рекламы

```bash
# Включить и добавить списки
curl -X PUT -H "X-API-Token: <токен>" \
    -H "Content-Type: application/json" \
    -d '{
        "adblock": {
            "enabled": true,
            "lists": [
                "https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt",
                "https://easylist-downloads.adblockplus.org/easylist.txt"
            ]
        }
    }' \
    http://192.168.1.1:8080/api/v1/dns/settings
```

---

## 10. Настройка DPI обхода

### 10.1. API endpoints

```bash
# Получить настройки
curl -H "X-API-Token: <токен>" \
    http://192.168.1.1:8080/api/v1/dpi/settings

# Включить обход
curl -X PUT -H "X-API-Token: <токен>" \
    -H "Content-Type: application/json" \
    -d '{
        "enabled": true,
        "mode": "auto",
        "bypass_domains": ["youtube.com", "instagram.com"]
    }' \
    http://192.168.1.1:8080/api/v1/dpi/settings
```

---

## 11. Финальная проверка

### 11.1. Чек-лист

- [ ] Сервис запущен: `/opt/etc/init.d/S50rguard status`
- [ ] API доступен: `curl http://192.168.1.1:8080/health`
- [ ] VPN подключён: `/api/v1/vpn/status`
- [ ] DNS работает: `nslookup example.com 192.168.1.1`
- [ ] Логи пишутся: `tail -f /opt/var/log/routeguard/routeguard.log`

### 11.2. Тестовые команды

```bash
# Статус сервиса
/opt/etc/init.d/S50rguard status

# Логи в реальном времени
tail -f /opt/var/log/routeguard/routeguard.log

# Проверка портов
netstat -tlnp | grep -E '8080|53'

# Проверка процессов
ps | grep routeguard

# Тест API
curl http://192.168.1.1:8080/health
curl -H "X-API-Token: <токен>" http://192.168.1.1:8080/api/v1/system/status
```

### 11.3. Создание бэкапа

```bash
# Бэкап конфигурации
tar -czf /tmp/routeguard-backup-$(date +%Y%m%d).tar.gz \
    /opt/etc/routeguard /opt/var/lib/routeguard

# Через API
curl -X POST -H "X-API-Token: <токен>" \
    http://192.168.1.1:8080/api/v1/system/backup
```

---

## 12. Решение проблем

### Проблема 1: Сервис не запускается

```bash
# Проверка логов
cat /opt/var/log/routeguard/routeguard.log

# Проверка конфига
cat /opt/etc/routeguard/config.json | jq .

# Проверка порта
netstat -tlnp | grep 8080
# Если занят — измените порт в config.json
```

### Проблема 2: API не отвечает

```bash
# Проверка процесса
ps | grep routeguard

# Перезапуск
/opt/etc/init.d/S50rguard restart

# Проверка firewall
iptables -L -n | grep 8080
```

### Проблема 3: VPN не подключается

```bash
# Проверка sing-box
sing-box version

# Проверка конфигурации профиля
cat /opt/etc/routeguard/profiles/*.json

# Тест подключения
sing-box run -c /opt/etc/routeguard/profiles/<profile>.json
```

### Проблема 4: Ошибка архитектуры

```bash
# Проверка бинарника
file /opt/bin/routeguard

# Должно соответствовать:
# MIPS: ELF 32-bit MSB executable, MIPS
# ARM: ELF 32-bit LSB executable, ARM
# x86: ELF 64-bit LSB executable, x86-64
```

### Проблема 5: Мало памяти

```bash
# Очистка кэша
echo 3 > /proc/sys/vm/drop_caches

# Удаление старых логов
rm /opt/var/log/routeguard/*.log.*

# Перезагрузка
reboot
```

---

## 📞 Поддержка и ресурсы

| Ресурс | Ссылка |
|--------|--------|
| README | [README.md](README.md) |
| GitHub Issues | https://github.com/alexandr-kuz/RouteGuard/issues |
| Keenetic KB | https://kb.keenetic.ru/ |
| Entware | https://github.com/Entware/Entware |
| sing-box | https://sing-box.sagernet.org/ |

---

## 📝 Журнал изменений

| Дата | Версия | Изменения |
|------|--------|-----------|
| 2026-02-23 | 0.1.0 | Актуализирована инструкция по установке |
| 2024-01-01 | 0.1.0 | Начальная версия документа |

---

**RouteGuard** © 2026. Сделано с ❤️ для свободного интернета.
