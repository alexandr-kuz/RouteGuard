# 📦 Инструкция по публикации релиза RouteGuard v0.1.0

## Подготовленные файлы

Все файлы находятся в папке `dist/`:

| Файл | Размер | Назначение |
|------|--------|------------|
| `routeguard-mips` | 9.9 MB | Для MIPS роутеров (Keenetic Start, Lite, Extra, Omni) |
| `routeguard-arm` | 8.8 MB | Для ARM роутеров (Keenetic Giga, Ultra, Pro) |
| `routeguard-amd64` | 9.2 MB | Для x86_64 роутеров (Keenetic на Intel) |
| `install.sh` | 16 KB | Скрипт установки |
| `uninstall.sh` | 9 KB | Скрипт удаления |
| `frontend.zip` | 43 KB | Frontend (Vue 3) |

---

## Способ 1: Публикация через GitHub Web UI (рекомендуется)

### Шаг 1: Перейдите на страницу релизов

Откройте: **https://github.com/alexandr-kuz/RouteGuard/releases**

### Шаг 2: Создайте новый релиз

Нажмите кнопку **"Draft a new release"**

### Шаг 3: Заполните информацию о релизе

**Tag version:** `v0.1.0`

**Target:** Выберите ветку `main` (или мастер)

**Release title:** `RouteGuard v0.1.0`

**Description:**
```markdown
## 📦 RouteGuard v0.1.0 — Начальный релиз

Универсальная VPN-платформа для роутеров Keenetic с Entware.

### ✨ Возможности

- 🔐 VPN Менеджер (WireGuard, VLESS, Hysteria2, Shadowsocks, Trojan)
- 🛣️ Маршрутизация трафика (Domain/GeoIP/CIDR)
- 🌐 DNS с блокировкой рекламы
- 🚀 Обход DPI

### 🚀 Быстрая установка

```bash
# Обновление пакетов
opkg update

# Установка curl
opkg install curl

# Установка RouteGuard
curl -sL https://github.com/alexandr-kuz/RouteGuard/releases/download/v0.1.0/install.sh | sh
```

### 📋 Требования

- Entware на роутере
- Архитектура: MIPS, ARM, или x86_64
- Свободно: ≥100 MB места, ≥128 MB RAM

### 📝 Документация

- [README](https://github.com/alexandr-kuz/RouteGuard/blob/main/README.md)
- [INSTALL_PLAN](https://github.com/alexandr-kuz/RouteGuard/blob/main/INSTALL_PLAN.md)

### 🔧 Изменения в v0.1.0

- Начальный релиз
- Базовая функциональность VPN
- Маршрутизация по доменам
- DNS сервер
- DPI обход
- Web UI (Vue 3)
```

### Шаг 4: Загрузите файлы

Перетащите файлы из папки `dist/` в поле **"Attach binaries by dropping them here or selecting them"**:

- ✅ `routeguard-mips`
- ✅ `routeguard-arm`
- ✅ `routeguard-amd64`
- ✅ `install.sh`
- ✅ `uninstall.sh`
- ✅ `frontend.zip`

### Шаг 5: Опубликуйте

- Выберите **"Set as the latest release"**
- Нажмите **"Publish release"**

---

## Способ 2: Публикация через GitHub CLI

### Требования

Установите GitHub CLI: https://cli.github.com/

```powershell
# Windows
winget install GitHub.cli

# Проверка установки
gh --version
```

### Публикация

```powershell
# Авторизация
gh auth login

# Перейдите в директорию проекта
cd c:\apk\RouteGuard

# Создайте и опубликуйте релиз
gh release create v0.1.0 ^
  dist/routeguard-mips ^
  dist/routeguard-arm ^
  dist/routeguard-amd64 ^
  dist/install.sh ^
  dist/uninstall.sh ^
  dist/frontend.zip ^
  --title "RouteGuard v0.1.0" ^
  --notes "Начальный релиз RouteGuard" ^
  --latest
```

---

## Проверка после публикации

### 1. Проверьте доступность файлов

```bash
# Проверка install.sh
curl -I https://github.com/alexandr-kuz/RouteGuard/releases/download/v0.1.0/install.sh

# Проверка бинарника
curl -I https://github.com/alexandr-kuz/RouteGuard/releases/download/v0.1.0/routeguard-mips
```

### 2. Тест установки

```bash
# На роутере или в тестовой среде
curl -sL https://github.com/alexandr-kuz/RouteGuard/releases/download/v0.1.0/install.sh -o /tmp/test-install.sh
chmod +x /tmp/test-install.sh
cat /tmp/test-install.sh | head -20
```

---

## Ссылки после публикации

- **Страница релиза:** https://github.com/alexandr-kuz/RouteGuard/releases/tag/v0.1.0
- **Последний релиз:** https://github.com/alexandr-kuz/RouteGuard/releases/latest
- **Install скрипт:** https://github.com/alexandr-kuz/RouteGuard/releases/download/v0.1.0/install.sh
- **Uninstall скрипт:** https://github.com/alexandr-kuz/RouteGuard/releases/download/v0.1.0/uninstall.sh

---

## Дата публикации

**Планируемая дата:** 23 февраля 2026

**Статус:** ✅ Готов к публикации
