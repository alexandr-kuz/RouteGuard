#!/usr/bin/env python3
"""
RouteGuard - легковесный HTTP-сервер для управления VPN
"""

import json
import os
import sys
import subprocess
import secrets
import logging
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import threading
import socketserver

# Конфигурация
CONFIG_PATH = os.environ.get('RG_CONFIG', '/opt/etc/routeguard/config.json')
DEFAULT_PORT = 8080

# Настройка логирования
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger('routeguard')


class RouteGuardHandler(BaseHTTPRequestHandler):
    """HTTP обработчик для RouteGuard API"""
    
    api_token = None
    config = {}
    
    def log_message(self, format, *args):
        logger.info("%s - %s" % (self.address_string(), format % args))
    
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
        self.send_json({'error': message}, status)
    
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
            self.send_json({'status': 'ok', 'version': '0.2.1'})
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
            self.send_json({'config': self.config})
            return

        # Web UI - главный файл
        if path == '/' or path == '/index.html':
            self.serve_file('frontend/index.html', 'text/html; charset=utf-8')
            return

        # Статические файлы
        if path.startswith('/assets/'):
            filename = path[1:].replace('\\', '/')  # assets/...
            ext = path.split('.')[-1] if '.' in path else ''
            content_type = {
                'js': 'application/javascript',
                'css': 'text/css',
                'map': 'application/json',
                'json': 'application/json'
            }.get(ext, 'application/octet-stream')
            self.serve_file(filename, content_type)
            return

        # Favicon
        if path == '/favicon.ico':
            self.send_error_json('Not Found', 404)
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
        
        if path == '/api/routing/update':
            self.handle_routing_update()
            return
        
        self.send_error_json('Not Found', 404)
    
    def handle_login(self):
        """Логин"""
        try:
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length)
            data = json.loads(body) if body else {}
            
            # Простая проверка - токен хранится в конфиге
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
            logger.info(f'Connecting to VPN profile: {profile}')
            
            # Здесь будет логика подключения sing-box
            result = self.run_vpn_command('connect', profile)
            
            self.send_json({'success': result, 'profile': profile})
        except Exception as e:
            logger.error(f'VPN connect error: {e}')
            self.send_error_json(str(e), 400)
    
    def handle_vpn_disconnect(self):
        """Отключение от VPN"""
        try:
            logger.info('Disconnecting from VPN')
            result = self.run_vpn_command('disconnect')
            self.send_json({'success': result})
        except Exception as e:
            logger.error(f'VPN disconnect error: {e}')
            self.send_error_json(str(e), 400)
    
    def handle_routing_update(self):
        """Обновление маршрутов"""
        try:
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length)
            data = json.loads(body) if body else {}
            
            logger.info(f'Updating routing: {data}')
            result = self.update_routing(data)
            
            self.send_json({'success': result})
        except Exception as e:
            logger.error(f'Routing update error: {e}')
            self.send_error_json(str(e), 400)
    
    def get_status(self):
        """Получить статус системы"""
        status = {
            'version': '0.2.1',
            'vpn': {
                'enabled': self.config.get('vpn', {}).get('enabled', False),
                'connected': False,
                'profile': None
            },
            'routing': {
                'enabled': self.config.get('routing', {}).get('enabled', False),
                'mode': self.config.get('routing', {}).get('mode', 'direct')
            },
            'dns': {
                'enabled': self.config.get('dns', {}).get('enabled', False),
                'port': self.config.get('dns', {}).get('port', 53)
            },
            'dpi': {
                'enabled': self.config.get('dpi', {}).get('enabled', False)
            }
        }
        
        # Проверка статуса VPN
        try:
            result = subprocess.run(
                ['pgrep', '-f', 'sing-box'],
                capture_output=True,
                timeout=5
            )
            status['vpn']['connected'] = result.returncode == 0
        except:
            pass
        
        return status
    
    def run_vpn_command(self, action, profile=None):
        """Выполнить команду VPN"""
        try:
            if action == 'connect':
                config_file = f"/opt/etc/routeguard/profiles/{profile}.json"
                if os.path.exists(config_file):
                    subprocess.Popen(
                        ['sing-box', 'run', '-c', config_file],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL
                    )
                    return True
            elif action == 'disconnect':
                subprocess.run(['pkill', '-f', 'sing-box'], timeout=5)
                return True
        except Exception as e:
            logger.error(f'VPN command error: {e}')
        return False
    
    def update_routing(self, data):
        """Обновить маршрутизацию"""
        try:
            # Добавить маршруты через ip route
            routes = data.get('routes', [])
            for route in routes:
                cmd = ['ip', 'route', 'add', route]
                subprocess.run(cmd, timeout=5, capture_output=True)
            return True
        except Exception as e:
            logger.error(f'Routing error: {e}')
        return False
    
    def serve_file(self, path, content_type):
        """Отдать файл с правильным Content-Type"""
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

    def serve_frontend(self, path):
        """Отдать файлы фронтенда (устаревшее)"""
        self.serve_file(f'frontend/{path}', 'text/html; charset=utf-8')


def load_config():
    """Загрузить конфигурацию"""
    if os.path.exists(CONFIG_PATH):
        with open(CONFIG_PATH, 'r', encoding='utf-8') as f:
            return json.load(f)
    return {}


def main():
    """Точка входа"""
    logger.info('Запуск RouteGuard Python сервера...')
    
    # Загрузка конфигурации
    config = load_config()
    RouteGuardHandler.api_token = config.get('api', {}).get('token', '')
    RouteGuardHandler.config = config

    # Порт из переменной окружения или конфига
    port = int(os.environ.get('RG_PORT', config.get('api', {}).get('port', DEFAULT_PORT)))
    if not isinstance(port, int):
        port = int(port)
    host = config.get('api', {}).get('host', '0.0.0.0')

    logger.info(f'Слушаю {host}:{port}')
    
    # Запуск сервера
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer((host, port), RouteGuardHandler) as httpd:
        logger.info('RouteGuard готов к работе')
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            logger.info('Остановка сервера...')


if __name__ == '__main__':
    main()
