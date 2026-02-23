<template>
  <div id="app">
    <div class="container">
      <h1>RouteGuard</h1>
      <p class="subtitle">Универсальная VPN-платформа для Entware</p>
      <div class="status">
        <p>Версия: 0.1.0</p>
        <p>Статус: Разработка</p>
      </div>
      <div class="info">
        <p>Frontend в разработке. Backend доступен по адресу: <code>http://localhost:8080</code></p>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
</script>

<style>
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
}

#app {
  color: white;
}

.container {
  text-align: center;
  padding: 2rem;
  background: rgba(255, 255, 255, 0.1);
  border-radius: 20px;
  backdrop-filter: blur(10px);
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
}

h1 {
  font-size: 3rem;
  margin-bottom: 0.5rem;
}

.subtitle {
  font-size: 1.2rem;
  opacity: 0.9;
  margin-bottom: 2rem;
}

.status {
  background: rgba(255, 255, 255, 0.2);
  padding: 1rem 2rem;
  border-radius: 10px;
  margin-bottom: 1rem;
}

.status p {
  margin: 0.5rem 0;
}

.info {
  font-size: 0.9rem;
  opacity: 0.8;
}

.info code {
  background: rgba(255, 255, 255, 0.2);
  padding: 0.2rem 0.5rem;
  border-radius: 4px;
}
</style>
