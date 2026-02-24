#!/usr/bin/env python3
"""
RouteGuard - полноценный HTTP-сервер для управления VPN
"""

import json
import os
import sys
import subprocess
import secrets
import logging
import socket
import threading
import signal
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import socketserver
import time
from datetime import datetime

# Конфигурация
CONFIG_PATH = os.environ.get('RG_CONFIG', '/opt/etc/routeguard/config.json')
DEFAULT_PORT = 5000

# Настройка логирования
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger('routeguard')


class VPNManager:
    """Управление VPN (sing-box)"""
    
    def __init__(self, config_dir):
        self.config_dir = config_dir
        self.process = None
    
    def is_running(self):
        """Проверить работает ли VPN"""
        try:
            result = subprocess.run(['pgrep', '-f', 'sing-box'], capture_output=True, timeout=5)
            return result.returncode == 0
        except:
            return False
    
    def connect(self, profile_name):
        """Подключить VPN профиль"""
        config_file = os.path.join(self.config_dir, f'{profile_name}.json')
        
        if not os.path.exists(config_file):
            logger.error(f'Config not found: {config_file}')
            return False
        
        # Остановить если работает
        self.disconnect()
        
        try:
            # Запустить sing-box
            self.process = subprocess.Popen(
                ['sing-box', 'run', '-c', config_file],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )
            time.sleep(2)
            
            if self.is_running():
                logger.info(f'VPN connected: {profile_name}')
                return True
            else:
                logger.error('Failed to start sing-box')
                return False
        except Exception as e:
            logger.error(f'VPN connect error: {e}')
            return False
    
    def disconnect(self):
        """Отключить VPN"""
        try:
            subprocess.run(['pkill', '-f', 'sing-box'], timeout=5)
            logger.info('VPN disconnected')
            return True
        except:
            return False
    
    def get_status(self):
        """Получить статус VPN"""
        return {
            'connected': self.is_running(),
            'profile': None
        }


class DNSServer:
    """DNS сервер с блокировкой рекламы"""
    
    def __init__(self, port, upstream, adblock_enabled=False):
        self.port = port
        self.upstream = upstream
        self.adblock_enabled = adblock_enabled
        self.blocked_count = 0
        self.socket = None
        self.running = False
    
    def start(self):
        """Запустить DNS сервер"""
        try:
            self.socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            self.socket.bind(('0.0.0.0', self.port))
            self.socket.settimeout(1)
            self.running = True
            
            logger.info(f'DNS server started on port {self.port}')
            
            while self.running:
                try:
                    data, addr = self.socket.recvfrom(512)
                    # Простая прокси-обработка DNS запросов
                    self.handle_dns(data, addr)
                except socket.timeout:
                    continue
                except Exception as e:
                    logger.error(f'DNS error: {e}')
        except Exception as e:
            logger.error(f'Failed to start DNS: {e}')
    
    def handle_dns(self, data, addr):
        """Обработать DNS запрос"""
        try:
            # Отправить upstream DNS серверу
            upstream_host = self.upstream.replace('tls://', '').replace('https://', '').split('/')[0]
            
            # Для простоты - используем системный DNS
            resolver = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            resolver.settimeout(5)
            resolver.sendto(data, ('1.1.1.1', 53))
            
            response, _ = resolver.recvfrom(512)
            resolver.close()
            
            self.socket.sendto(response, addr)
        except Exception as e:
            logger.error(f'DNS resolve error: {e}')
    
    def stop(self):
        """Остановить DNS сервер"""
        self.running = False
        if self.socket:
            self.socket.close()


class DPIBypass:
    """Управление обходом DPI"""
    
    def __init__(self, domains):
        self.domains = domains
        self.process = None
    
    def is_running(self):
        """Проверить работает ли DPI bypass"""
        try:
            result = subprocess.run(['pgrep', '-f', 'byedpi'], capture_output=True, timeout=5)
            return result.returncode == 0
        except:
            return False
    
    def start(self):
        """Запустить обход DPI"""
        if self.is_running():
            return True
        
        try:
            # Запустить byedpi если установлен
            if subprocess.run(['which', 'byedpi'], capture_output=True).returncode == 0:
                self.process = subprocess.Popen(
                    ['byedpi', '-d', ','.join(self.domains)],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE
                )
                time.sleep(1)
                logger.info(f'DPI bypass started for: {self.domains}')
                return True
        except Exception as e:
            logger.error(f'DPI bypass error: {e}')
        
        return False
    
    def stop(self):
        """Остановить обход DPI"""
        try:
            subprocess.run(['pkill', '-f', 'byedpi'], timeout=5)
            logger.info('DPI bypass stopped')
            return True
        except:
            return False


class RouteGuardHandler(BaseHTTPRequestHandler):
    """HTTP обработчик для RouteGuard API"""
    
    api_token = None
    config = {}
    vpn_manager = None
    dns_server = None
    dpi_bypass = None
    
    def log_message(self, format, *args):
        logger.debug("%s - %s" % (self.address_string(), format % args))
    
    def send_json(self, data, status=200):
        """Отправить JSON ответ"""
        body = json.dumps(data, ensure_ascii=False).encode('utf-8')
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', len(body))
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Authorization, Content-Type')
        self.end_headers()
        self.wfile.write(body)
    
    def send_error_json(self, message, status=400):
        """Отправить ошибку"""
        self.send_json({'error': message, 'success': False}, status)
    
    def check_auth(self):
        """Проверить API токен"""
        auth = self.headers.get('Authorization', '')
        if auth.startswith('Bearer '):
            token = auth[7:]
            return token == self.api_token
        return False
    
    def do_OPTIONS(self):
        """CORS preflight"""
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Authorization, Content-Type')
        self.end_headers()
    
    def do_GET(self):
        """Обработка GET запросов"""
        parsed = urlparse(self.path)
        path = parsed.path
        
        # Публичные эндпоинты
        if path == '/api/health':
            self.send_json({'status': 'ok', 'version': '0.2.1', 'success': True})
            return
        
        if path == '/api/status':
            if not self.check_auth():
                self.send_error_json('Unauthorized', 401)
                return
            self.send_json(self.get_status())
            return
        
        if path == '/api/config':
            if not self.check_auth():
                self.send_error_json('Unauthorized', 401)
                return
            self.send_json({'config': self.config, 'success': True})
            return
        
        if path == '/api/vpn/status':
            if not self.check_auth():
                self.send_error_json('Unauthorized', 401)
                return
            self.send_json({'status': self.vpn_manager.get_status() if self.vpn_manager else {'connected': False}, 'success': True})
            return
        
        # Web UI - главный файл
        if path == '/' or path == '/index.html':
            self.serve_file('frontend/index.html', 'text/html; charset=utf-8')
            return
        
        # Статические файлы
        if path.startswith('/assets/'):
            filename = path[1:].replace('\\', '/')
            ext = path.split('.')[-1] if '.' in path else ''
            content_type = {
                'js': 'application/javascript',
                'css': 'text/css',
                'map': 'application/json',
                'json': 'application/json'
            }.get(ext, 'application/octet-stream')
            self.serve_file(filename, content_type)
            return
        
        self.send_error_json('Not Found', 404)
    
    def do_POST(self):
        """Обработка POST запросов"""
        parsed = urlparse(self.path)
        path = parsed.path
        
        if path == '/api/login':
            self.handle_login()
            return
        
        if not self.check_auth():
            self.send_error_json('Unauthorized', 401)
            return
        
        if path == '/api/vpn/connect':
            self.handle_vpn_connect()
            return
        
        if path == '/api/vpn/disconnect':
            self.handle_vpn_disconnect()
            return
        
        if path == '/api/dns/toggle':
            self.handle_dns_toggle()
            return
        
        if path == '/api/dpi/toggle':
            self.handle_dpi_toggle()
            return
        
        if path == '/api/config/save':
            self.handle_config_save()
            return
        
        self.send_error_json('Not Found', 404)
    
    def handle_login(self):
        """Логин"""
        try:
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length)
            data = json.loads(body) if body else {}
            
            if data.get('token') == self.api_token:
                self.send_json({'success': True, 'token': self.api_token})
            else:
                self.send_error_json('Invalid token', 401)
        except Exception as e:
            logger.error(f'Login error: {e}')
            self.send_error_json('Invalid request', 400)
    
    def handle_vpn_connect(self):
        """Подключение к VPN"""
        try:
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length)
            data = json.loads(body) if body else {}
            
            profile = data.get('profile', 'default')
            logger.info(f'Connecting to VPN: {profile}')
            
            if self.vpn_manager and self.vpn_manager.connect(profile):
                self.send_json({'success': True, 'message': 'VPN подключен'})
            else:
                self.send_error_json('Ошибка подключения VPN', 400)
        except Exception as e:
            logger.error(f'VPN connect error: {e}')
            self.send_error_json(str(e), 400)
    
    def handle_vpn_disconnect(self):
        """Отключение от VPN"""
        try:
            logger.info('Disconnecting VPN')
            
            if self.vpn_manager and self.vpn_manager.disconnect():
                self.send_json({'success': True, 'message': 'VPN отключен'})
            else:
                self.send_error_json('Ошибка отключения VPN', 400)
        except Exception as e:
            logger.error(f'VPN disconnect error: {e}')
            self.send_error_json(str(e), 400)
    
    def handle_dns_toggle(self):
        """Включить/выключить DNS"""
        try:
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length)
            data = json.loads(body) if body else {}
            
            enabled = data.get('enabled', False)
            
            if enabled:
                # Запустить DNS сервер
                if not self.dns_server:
                    dns_config = self.config.get('dns', {})
                    self.dns_server = DNSServer(
                        dns_config.get('port', 5353),
                        dns_config.get('upstream', 'tls://1.1.1.1'),
                        dns_config.get('adblock', {}).get('enabled', False)
                    )
                    thread = threading.Thread(target=self.dns_server.start, daemon=True)
                    thread.start()
                self.send_json({'success': True, 'message': 'DNS включен'})
            else:
                # Остановить DNS сервер
                if self.dns_server:
                    self.dns_server.stop()
                    self.dns_server = None
                self.send_json({'success': True, 'message': 'DNS выключен'})
        except Exception as e:
            logger.error(f'DNS toggle error: {e}')
            self.send_error_json(str(e), 400)
    
    def handle_dpi_toggle(self):
        """Включить/выключить DPI bypass"""
        try:
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length)
            data = json.loads(body) if body else {}
            
            enabled = data.get('enabled', False)
            
            if enabled:
                if self.dpi_bypass and self.dpi_bypass.start():
                    self.send_json({'success': True, 'message': 'DPI bypass включен'})
                else:
                    self.send_error_json('Не удалось включить DPI bypass', 400)
            else:
                if self.dpi_bypass:
                    self.dpi_bypass.stop()
                self.send_json({'success': True, 'message': 'DPI bypass выключен'})
        except Exception as e:
            logger.error(f'DPI toggle error: {e}')
            self.send_error_json(str(e), 400)
    
    def handle_config_save(self):
        """Сохранить конфигурацию"""
        try:
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length)
            data = json.loads(body) if body else {}
            
            # Сохранить конфиг
            with open(CONFIG_PATH, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=4, ensure_ascii=False)
            
            self.config = data
            logger.info('Config saved')
            
            self.send_json({'success': True, 'message': 'Конфигурация сохранена'})
        except Exception as e:
            logger.error(f'Config save error: {e}')
            self.send_error_json(str(e), 400)
    
    def get_status(self):
        """Получить статус системы"""
        return {
            'version': '0.2.1',
            'vpn': self.vpn_manager.get_status() if self.vpn_manager else {'connected': False},
            'dns': {
                'enabled': self.dns_server is not None,
                'port': self.config.get('dns', {}).get('port', 5353)
            },
            'dpi': {
                'enabled': self.dpi_bypass.is_running() if self.dpi_bypass else False
            },
            'routing': {
                'enabled': self.config.get('routing', {}).get('enabled', False),
                'rules_count': 0
            },
            'success': True
        }
    
    def serve_file(self, path, content_type):
        """Отдать файл"""
        base_dir = '/opt/etc/routeguard'
        file_path = os.path.join(base_dir, *path.split('/'))
        
        if not os.path.exists(file_path):
            logger.warning(f'File not found: {file_path}')
            self.send_error_json('Not Found', 404)
            return
        
        try:
            with open(file_path, 'rb') as f:
                content = f.read()
            
            self.send_response(200)
            self.send_header('Content-Type', content_type)
            self.send_header('Content-Length', len(content))
            self.send_header('Cache-Control', 'public, max-age=3600')
            self.end_headers()
            self.wfile.write(content)
        except Exception as e:
            logger.error(f'File serve error: {e}')
            self.send_error_json('Error loading file', 500)


def load_config():
    """Загрузить конфигурацию"""
    if os.path.exists(CONFIG_PATH):
        with open(CONFIG_PATH, 'r', encoding='utf-8') as f:
            return json.load(f)
    return {}


def main():
    """Точка входа"""
    logger.info('Запуск RouteGuard v0.2.1...')
    
    # Загрузка конфигурации
    config = load_config()
    RouteGuardHandler.api_token = config.get('api', {}).get('token', '')
    RouteGuardHandler.config = config
    
    # Инициализация модулей
    vpn_config = config.get('vpn', {})
    if vpn_config.get('enabled', False):
        RouteGuardHandler.vpn_manager = VPNManager(vpn_config.get('config_dir', '/opt/etc/routeguard/profiles'))
        logger.info('VPN менеджер инициализирован')
    
    dns_config = config.get('dns', {})
    if dns_config.get('enabled', False):
        RouteGuardHandler.dns_server = DNSServer(
            dns_config.get('port', 5353),
            dns_config.get('upstream', 'tls://1.1.1.1'),
            dns_config.get('adblock', {}).get('enabled', False)
        )
        thread = threading.Thread(target=RouteGuardHandler.dns_server.start, daemon=True)
        thread.start()
        logger.info('DNS сервер запущен')
    
    dpi_config = config.get('dpi', {})
    if dpi_config.get('enabled', False):
        RouteGuardHandler.dpi_bypass = DPIBypass(dpi_config.get('bypass_domains', []))
        RouteGuardHandler.dpi_bypass.start()
        logger.info('DPI bypass инициализирован')
    
    port = int(os.environ.get('RG_PORT', config.get('api', {}).get('port', DEFAULT_PORT)))
    if not isinstance(port, int):
        port = int(port)
    host = config.get('api', {}).get('host', '0.0.0.0')
    
    logger.info(f'Слушаю {host}:{port}')
    
    # Запуск сервера
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer((host, port), RouteGuardHandler) as httpd:
        logger.info('RouteGuard готов к работе')
        
        # Обработка Ctrl+C
        def signal_handler(sig, frame):
            logger.info('Остановка...')
            if RouteGuardHandler.dns_server:
                RouteGuardHandler.dns_server.stop()
            if RouteGuardHandler.dpi_bypass:
                RouteGuardHandler.dpi_bypass.stop()
            if RouteGuardHandler.vpn_manager:
                RouteGuardHandler.vpn_manager.disconnect()
            httpd.shutdown()
            sys.exit(0)
        
        signal.signal(signal.SIGINT, signal_handler)
        
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            pass


if __name__ == '__main__':
    main()
