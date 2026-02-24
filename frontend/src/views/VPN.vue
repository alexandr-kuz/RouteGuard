<template>
  <div class="vpn-page">
    <div class="card">
      <h3>Статус VPN</h3>
      <div class="status-indicator" :class="{ active: vpnConnected }">
        <span class="dot">{{ vpnConnected ? '●' : '○' }}</span>
        <span>{{ vpnConnected ? 'Подключено' : 'Отключено' }}</span>
      </div>
      
      <div class="profiles">
        <h4>Профили</h4>
        <div v-for="profile in profiles" :key="profile.name" class="profile-item">
          <span>{{ profile.name }}</span>
          <button 
            class="btn" 
            :class="profile.enabled ? 'btn-success' : 'btn-primary'"
            @click="toggleProfile(profile)"
          >
            {{ profile.enabled ? 'Отключить' : 'Подключить' }}
          </button>
        </div>
      </div>
      
      <div class="actions">
        <button class="btn btn-primary" @click="connectVpn" :disabled="vpnConnected">
          Подключить
        </button>
        <button class="btn btn-danger" @click="disconnectVpn" :disabled="!vpnConnected">
          Отключить
        </button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'

const vpnConnected = ref(false)
const profiles = ref([
  { name: 'Default', enabled: false },
  { name: 'Work', enabled: false }
])

const connectVpn = async () => {
  const token = localStorage.getItem('rg_token')
  try {
    const res = await fetch('/api/vpn/connect', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ profile: 'Default' })
    })
    const data = await res.json()
    if (data.success) {
      vpnConnected.value = true
      alert('VPN подключен!')
    }
  } catch (e) {
    alert('Ошибка подключения: ' + e)
  }
}

const disconnectVpn = async () => {
  const token = localStorage.getItem('rg_token')
  try {
    const res = await fetch('/api/vpn/disconnect', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      }
    })
    const data = await res.json()
    if (data.success) {
      vpnConnected.value = false
      alert('VPN отключен!')
    }
  } catch (e) {
    alert('Ошибка отключения: ' + e)
  }
}

const toggleProfile = (profile: any) => {
  profile.enabled = !profile.enabled
}

const checkStatus = async () => {
  const token = localStorage.getItem('rg_token')
  try {
    const res = await fetch('/api/vpn/status', {
      headers: { 'Authorization': `Bearer ${token}` }
    })
    const data = await res.json()
    vpnConnected.value = data.status?.connected || false
  } catch (e) {
    console.error(e)
  }
}

onMounted(() => {
  checkStatus()
  setInterval(checkStatus, 5000)
})
</script>

<style scoped>
.vpn-page {
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

.card {
  background: white;
  padding: 1.5rem;
  border-radius: 12px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
}

.status-indicator {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 1rem;
  background: #f3f4f6;
  border-radius: 8px;
  margin: 1rem 0;
  font-size: 1.125rem;
}

.status-indicator.active {
  background: #d1fae5;
  color: #065f46;
}

.dot {
  font-size: 1.5rem;
}

.profiles {
  margin: 1.5rem 0;
}

.profile-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.75rem 0;
  border-bottom: 1px solid #f3f4f6;
}

.actions {
  display: flex;
  gap: 1rem;
  margin-top: 1.5rem;
}

.btn {
  padding: 0.75rem 1.5rem;
  border: none;
  border-radius: 8px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.btn-primary {
  background: #4f46e5;
  color: white;
}

.btn-primary:hover:not(:disabled) {
  background: #4338ca;
}

.btn-success {
  background: #10b981;
  color: white;
}

.btn-danger {
  background: #ef4444;
  color: white;
}
</style>
