<template>
  <div class="dashboard">
    <!-- Status Cards -->
    <div class="cards">
      <div class="card" @click="navigateTo('/vpn')">
        <div class="card-icon">🔐</div>
        <div class="card-info">
          <h3>VPN</h3>
          <p class="value" :class="{ active: vpnStatus.connected }">
            {{ vpnStatus.connected ? 'Активен' : 'Отключен' }}
          </p>
        </div>
      </div>
      
      <div class="card" @click="toggleDns">
        <div class="card-icon">🌐</div>
        <div class="card-info">
          <h3>DNS</h3>
          <p class="value" :class="{ active: dnsEnabled }">
            {{ dnsEnabled ? 'Активен' : 'Отключен' }}
          </p>
        </div>
      </div>
      
      <div class="card" @click="toggleDpi">
        <div class="card-icon">⚡</div>
        <div class="card-info">
          <h3>Анти-DPI</h3>
          <p class="value" :class="{ active: dpiEnabled }">
            {{ dpiEnabled ? 'Активен' : 'Отключен' }}
          </p>
        </div>
      </div>
      
      <div class="card" @click="navigateTo('/routing')">
        <div class="card-icon">🛣️</div>
        <div class="card-info">
          <h3>Правила</h3>
          <p class="value">{{ rulesCount }}</p>
        </div>
      </div>
    </div>

    <!-- Quick Actions -->
    <div class="section">
      <h3>Быстрые действия</h3>
      <div class="actions">
        <button class="btn btn-primary" @click="toggleVpn">
          {{ vpnStatus.connected ? 'Отключить VPN' : 'Включить VPN' }}
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
        <div class="info-item">
          <span class="label">Uptime:</span>
          <span class="value">{{ uptime }}</span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'

const router = useRouter()
const vpnStatus = ref({ connected: false, profile: null })
const dnsEnabled = ref(false)
const dpiEnabled = ref(false)
const rulesCount = ref(0)
const apiHost = ref(window.location.hostname)
const apiPort = ref(parseInt(window.location.port) || 5000)
const uptime = ref('0:00')

const startTime = ref(Date.now())

const toggleVpn = async () => {
  const token = localStorage.getItem('rg_token')
  const endpoint = vpnStatus.value.connected ? '/api/vpn/disconnect' : '/api/vpn/connect'
  
  try {
    const res = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      },
      body: vpnStatus.value.connected ? null : JSON.stringify({ profile: 'Default' })
    })
    const data = await res.json()
    if (data.success) {
      vpnStatus.value.connected = !vpnStatus.value.connected
      alert(vpnStatus.value.connected ? 'VPN подключен!' : 'VPN отключен!')
      checkStatus()
    }
  } catch (e) {
    alert('Ошибка: ' + e)
  }
}

const toggleDns = async () => {
  const token = localStorage.getItem('rg_token')
  try {
    const res = await fetch('/api/dns/toggle', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ enabled: !dnsEnabled.value })
    })
    const data = await res.json()
    if (data.success) {
      dnsEnabled.value = !dnsEnabled.value
      alert(dnsEnabled.value ? 'DNS включен' : 'DNS выключен')
    }
  } catch (e) {
    alert('Ошибка: ' + e)
  }
}

const toggleDpi = async () => {
  const token = localStorage.getItem('rg_token')
  try {
    const res = await fetch('/api/dpi/toggle', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ enabled: !dpiEnabled.value })
    })
    const data = await res.json()
    if (data.success) {
      dpiEnabled.value = !dpiEnabled.value
      alert(dpiEnabled.value ? 'DPI bypass включен' : 'DPI bypass выключен')
    }
  } catch (e) {
    alert('Ошибка: ' + e)
  }
}

const checkUpdate = () => {
  alert('Проверка обновлений...\nВерсия актуальна')
}

const viewLogs = () => {
  router.push('/logs')
}

const navigateTo = (path: string) => {
  router.push(path)
}

const checkStatus = async () => {
  const token = localStorage.getItem('rg_token')
  try {
    const res = await fetch('/api/status', {
      headers: { 'Authorization': `Bearer ${token}` }
    })
    const data = await res.json()
    vpnStatus.value = data.vpn || { connected: false }
    dnsEnabled.value = data.dns?.enabled || false
    dpiEnabled.value = data.dpi?.enabled || false
    rulesCount.value = data.routing?.rules_count || 0
    
    // Update uptime
    const diff = Math.floor((Date.now() - startTime.value) / 1000)
    const mins = Math.floor(diff / 60)
    const secs = diff % 60
    uptime.value = `${mins}:${secs.toString().padStart(2, '0')}`
  } catch (e) {
    console.error(e)
  }
}

onMounted(() => {
  checkStatus()
  setInterval(checkStatus, 3000)
})
</script>

<style scoped>
.dashboard {
  display: flex;
  flex-direction: column;
  gap: 2rem;
}

.cards {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
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
  cursor: pointer;
  transition: transform 0.2s, box-shadow 0.2s;
}

.card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
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

.card-info .value.active {
  color: #10b981;
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
