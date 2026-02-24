<template>
  <div class="app">
    <!-- Sidebar -->
    <aside class="sidebar">
      <div class="logo">
        <h1>🛡️ RouteGuard</h1>
      </div>
      <nav class="menu">
        <router-link to="/" class="menu-item" active-class="active">
          <span class="icon">📊</span>
          <span>Главная</span>
        </router-link>
        <router-link to="/vpn" class="menu-item" active-class="active">
          <span class="icon">🔐</span>
          <span>VPN</span>
        </router-link>
        <router-link to="/routing" class="menu-item" active-class="active">
          <span class="icon">🛣️</span>
          <span>Маршрутизация</span>
        </router-link>
        <router-link to="/dns" class="menu-item" active-class="active">
          <span class="icon">🌐</span>
          <span>DNS</span>
        </router-link>
        <router-link to="/dpi" class="menu-item" active-class="active">
          <span class="icon">⚡</span>
          <span>Анти-DPI</span>
        </router-link>
        <router-link to="/settings" class="menu-item" active-class="active">
          <span class="icon">⚙️</span>
          <span>Настройки</span>
        </router-link>
      </nav>
      <div class="version">v0.2.1</div>
    </aside>

    <!-- Main Content -->
    <main class="main">
      <header class="header">
        <h2>{{ pageTitle }}</h2>
        <div class="status-bar">
          <span class="status-indicator" :class="{ online: isOnline }">
            {{ isOnline ? '●' : '●' }}
          </span>
          <span>{{ isOnline ? 'Подключено' : 'Отключено' }}</span>
        </div>
      </header>
      
      <div class="content">
        <router-view />
      </div>
    </main>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { useRoute } from 'vue-router'

const route = useRoute()
const isOnline = ref(true)

const pageTitle = computed(() => {
  const titles: Record<string, string> = {
    '/': 'Панель управления',
    '/vpn': 'VPN Менеджер',
    '/routing': 'Маршрутизация',
    '/dns': 'DNS',
    '/dpi': 'Анти-DPI',
    '/settings': 'Настройки'
  }
  return titles[route.path] || 'RouteGuard'
})
</script>

<style>
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

.app {
  display: flex;
  min-height: 100vh;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
}

.sidebar {
  width: 260px;
  background: linear-gradient(180deg, #1a1a2e 0%, #16213e 100%);
  color: white;
  padding: 1.5rem;
  position: fixed;
  height: 100vh;
  overflow-y: auto;
}

.logo h1 {
  font-size: 1.5rem;
  margin-bottom: 2rem;
  text-align: center;
}

.menu {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.menu-item {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.875rem 1rem;
  color: #a0a0a0;
  text-decoration: none;
  border-radius: 8px;
  transition: all 0.2s;
}

.menu-item:hover {
  background: rgba(255, 255, 255, 0.1);
  color: white;
}

.menu-item.active {
  background: #4f46e5;
  color: white;
}

.icon {
  font-size: 1.25rem;
}

.version {
  position: absolute;
  bottom: 1.5rem;
  left: 1.5rem;
  font-size: 0.875rem;
  color: #666;
}

.main {
  margin-left: 260px;
  flex: 1;
  background: #f5f7fa;
}

.header {
  background: white;
  padding: 1.5rem 2rem;
  display: flex;
  justify-content: space-between;
  align-items: center;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
}

.header h2 {
  font-size: 1.5rem;
  color: #1a1a2e;
}

.status-bar {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  color: #666;
}

.status-indicator {
  color: #ef4444;
}

.status-indicator.online {
  color: #10b981;
}

.content {
  padding: 2rem;
}
</style>
