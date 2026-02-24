<template>
  <div class="dashboard">
    <!-- Status Cards -->
    <div class="cards">
      <div class="card">
        <div class="card-icon">🔐</div>
        <div class="card-info">
          <h3>VPN Статус</h3>
          <p class="value">{{ vpnStatus }}</p>
        </div>
      </div>
      
      <div class="card">
        <div class="card-icon">🛣️</div>
        <div class="card-info">
          <h3>Правила</h3>
          <p class="value">{{ rulesCount }}</p>
        </div>
      </div>
      
      <div class="card">
        <div class="card-icon">🌐</div>
        <div class="card-info">
          <h3>DNS</h3>
          <p class="value">{{ dnsStatus }}</p>
        </div>
      </div>
      
      <div class="card">
        <div class="card-icon">⚡</div>
        <div class="card-info">
          <h3>Анти-DPI</h3>
          <p class="value">{{ dpiStatus }}</p>
        </div>
      </div>
    </div>

    <!-- Quick Actions -->
    <div class="section">
      <h3>Быстрые действия</h3>
      <div class="actions">
        <button class="btn btn-primary" @click="toggleVpn">
          {{ vpnEnabled ? 'Отключить VPN' : 'Включить VPN' }}
        </button>
        <button class="btn btn-secondary" @click="checkUpdate">
          Проверить обновления
        </button>
        <button class="btn btn-secondary" @click="viewLogs">
          Логи
        </button>
      </div>
    </div>

    <!-- Info -->
    <div class="section">
      <h3>Информация</h3>
      <div class="info-grid">
        <div class="info-item">
          <span class="label">Версия:</span>
          <span class="value">0.2.1</span>
        </div>
        <div class="info-item">
          <span class="label">API:</span>
          <span class="value">http://{{ apiHost }}:{{ apiPort }}</span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'

const vpnEnabled = ref(false)
const apiHost = ref('192.168.1.1')
const apiPort = ref(5000)

const vpnStatus = computed(() => vpnEnabled.value ? 'Активен' : 'Отключен')
const rulesCount = ref(0)
const dnsStatus = ref('Активен')
const dpiStatus = ref('Отключен')

const toggleVpn = () => {
  vpnEnabled.value = !vpnEnabled.value
}

const checkUpdate = () => {
  alert('Проверка обновлений...')
}

const viewLogs = () => {
  alert('Открытие логов...')
}
</script>

<style scoped>
.dashboard {
  display: flex;
  flex-direction: column;
  gap: 2rem;
}

.cards {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: 1.5rem;
}

.card {
  background: white;
  padding: 1.5rem;
  border-radius: 12px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  display: flex;
  align-items: center;
  gap: 1rem;
}

.card-icon {
  font-size: 2.5rem;
}

.card-info h3 {
  font-size: 0.875rem;
  color: #666;
  font-weight: 500;
}

.card-info .value {
  font-size: 1.5rem;
  font-weight: 600;
  color: #1a1a2e;
  margin-top: 0.25rem;
}

.section {
  background: white;
  padding: 1.5rem;
  border-radius: 12px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
}

.section h3 {
  font-size: 1.125rem;
  color: #1a1a2e;
  margin-bottom: 1rem;
}

.actions {
  display: flex;
  gap: 1rem;
  flex-wrap: wrap;
}

.btn {
  padding: 0.75rem 1.5rem;
  border: none;
  border-radius: 8px;
  font-size: 0.875rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-primary {
  background: #4f46e5;
  color: white;
}

.btn-primary:hover {
  background: #4338ca;
}

.btn-secondary {
  background: #f3f4f6;
  color: #374151;
}

.btn-secondary:hover {
  background: #e5e7eb;
}

.info-grid {
  display: grid;
  gap: 1rem;
}

.info-item {
  display: flex;
  justify-content: space-between;
  padding: 0.75rem 0;
  border-bottom: 1px solid #f3f4f6;
}

.info-item .label {
  color: #666;
}

.info-item .value {
  color: #1a1a2e;
  font-weight: 500;
}
</style>
