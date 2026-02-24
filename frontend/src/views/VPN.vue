<template>
  <div class="vpn-page">
    <!-- Status -->
    <div class="status-card" :class="{ connected: vpnConnected }">
      <div class="status-icon">{{ vpnConnected ? '🟢' : '🔴' }}</div>
      <div class="status-info">
        <h3>VPN {{ vpnConnected ? 'подключен' : 'отключен' }}</h3>
        <p>{{ vpnConnected ? currentProfile : 'Выберите профиль для подключения' }}</p>
      </div>
    </div>

    <!-- Profiles List -->
    <div class="card">
      <div class="card-header">
        <h3>Профили VPN</h3>
        <button class="btn btn-primary" @click="showAddModal = true">+ Добавить</button>
      </div>
      
      <div v-if="profiles.length === 0" class="empty-state">
        <p>Нет профилей</p>
        <p class="hint">Добавьте первый профиль для подключения</p>
      </div>
      
      <div v-else class="profiles-list">
        <div v-for="(profile, index) in profiles" :key="index" class="profile-item" :class="{ active: profile.enabled }">
          <div class="profile-info">
            <h4>{{ profile.name }}</h4>
            <p class="protocol">{{ profile.protocol }}</p>
            <p v-if="profile.server" class="server">{{ profile.server }}</p>
          </div>
          <div class="profile-actions">
            <button class="btn btn-sm" @click="editProfile(profile)">✏️</button>
            <button class="btn btn-sm btn-danger" @click="deleteProfile(index)">🗑️</button>
            <button 
              class="btn btn-sm" 
              :class="profile.enabled ? 'btn-success' : 'btn-primary'"
              @click="toggleProfile(profile)"
            >
              {{ profile.enabled ? 'Откл' : 'Вкл' }}
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Quick Connect -->
    <div class="card">
      <h3>Быстрое подключение</h3>
      <div class="quick-actions">
        <button class="btn btn-primary" @click="quickConnect" :disabled="vpnConnected || profiles.length === 0">
          🔌 Подключить
        </button>
        <button class="btn btn-danger" @click="disconnect" :disabled="!vpnConnected">
          ⛔ Отключить
        </button>
      </div>
    </div>

    <!-- Add/Edit Modal -->
    <div v-if="showAddModal" class="modal-overlay" @click="showAddModal = false">
      <div class="modal" @click.stop>
        <div class="modal-header">
          <h3>{{ editingProfile ? 'Редактировать профиль' : 'Новый профиль' }}</h3>
          <button class="btn-close" @click="showAddModal = false">×</button>
        </div>
        
        <div class="modal-body">
          <div class="form-group">
            <label>Название</label>
            <input v-model="formData.name" type="text" placeholder="My VPN" />
          </div>
          
          <div class="form-group">
            <label>Протокол</label>
            <select v-model="formData.protocol">
              <option value="wireguard">WireGuard</option>
              <option value="vless">VLESS</option>
              <option value="shadowsocks">Shadowsocks</option>
              <option value="trojan">Trojan</option>
              <option value="hysteria2">Hysteria2</option>
              <option value="amnezia">AmneziaWG</option>
            </select>
          </div>
          
          <div class="form-group">
            <label>Способ добавления</label>
            <div class="radio-group">
              <label>
                <input type="radio" v-model="addMethod" value="url" />
                URL подписки
              </label>
              <label>
                <input type="radio" v-model="addMethod" value="manual" />
                Ручная настройка
              </label>
              <label>
                <input type="radio" v-model="addMethod" value="import" />
                Импорт конфига
              </label>
            </div>
          </div>
          
          <!-- URL Import -->
          <div v-if="addMethod === 'url'" class="form-group">
            <label>URL подписки</label>
            <input v-model="formData.url" type="url" placeholder="https://..." />
          </div>
          
          <!-- Manual Config -->
          <div v-if="addMethod === 'manual'" class="manual-config">
            <div class="form-group">
              <label>Адрес сервера</label>
              <input v-model="formData.server" type="text" placeholder="vpn.example.com" />
            </div>
            
            <div class="form-group">
              <label>Порт</label>
              <input v-model="formData.port" type="number" placeholder="51820" />
            </div>
            
            <div class="form-group" v-if="formData.protocol === 'wireguard'">
              <label>Приватный ключ</label>
              <textarea v-model="formData.privateKey" rows="3" placeholder="Private key..." />
            </div>
            
            <div class="form-group" v-if="formData.protocol === 'wireguard'">
              <label>Публичный ключ сервера</label>
              <textarea v-model="formData.publicKey" rows="3" placeholder="Public key..." />
            </div>
            
            <div class="form-group" v-if="formData.protocol === 'wireguard'">
              <label>Pre-shared ключ</label>
              <input v-model="formData.psk" type="text" placeholder="PSK (опционально)" />
            </div>
            
            <div class="form-group" v-if="formData.protocol === 'wireguard'">
              <label>Allowed IPs</label>
              <input v-model="formData.allowedIps" type="text" placeholder="0.0.0.0/0" />
            </div>
            
            <div class="form-group" v-if="formData.protocol === 'shadowsocks'">
              <label>Пароль</label>
              <input v-model="formData.password" type="text" placeholder="Password" />
            </div>
            
            <div class="form-group" v-if="formData.protocol === 'shadowsocks'">
              <label>Метод шифрования</label>
              <select v-model="formData.method">
                <option value="aes-256-gcm">AES-256-GCM</option>
                <option value="chacha20-ietf-poly1305">ChaCha20-IETF-Poly1305</option>
                <option value="aes-128-gcm">AES-128-GCM</option>
              </select>
            </div>
          </div>
          
          <!-- Import Config -->
          <div v-if="addMethod === 'import'" class="form-group">
            <label>Конфиг файл</label>
            <textarea v-model="formData.configText" rows="10" placeholder="Вставьте содержимое конфига..." />
          </div>
        </div>
        
        <div class="modal-footer">
          <button class="btn btn-secondary" @click="showAddModal = false">Отмена</button>
          <button class="btn btn-primary" @click="saveProfile">Сохранить</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'

const vpnConnected = ref(false)
const currentProfile = ref('')
const profiles = ref<any[]>([])
const showAddModal = ref(false)
const editingProfile = ref<any>(null)
const addMethod = ref('manual')

const formData = ref({
  name: '',
  protocol: 'wireguard',
  url: '',
  server: '',
  port: '',
  privateKey: '',
  publicKey: '',
  psk: '',
  allowedIps: '0.0.0.0/0',
  password: '',
  method: 'aes-256-gcm',
  configText: ''
})

const token = localStorage.getItem('rg_token') || ''

const loadProfiles = async () => {
  try {
    const res = await fetch('/api/config', {
      headers: { 'Authorization': `Bearer ${token}` }
    })
    const data = await res.json()
    // Загружаем профили из конфига или создаем дефолтные
    if (data.config?.profiles) {
      profiles.value = data.config.profiles
    }
  } catch (e) {
    console.error(e)
  }
}

const checkStatus = async () => {
  try {
    const res = await fetch('/api/vpn/status', {
      headers: { 'Authorization': `Bearer ${token}` }
    })
    const data = await res.json()
    vpnConnected.value = data.status?.connected || false
    currentProfile.value = data.status?.profile || ''
  } catch (e) {
    console.error(e)
  }
}

const quickConnect = async () => {
  if (profiles.value.length === 0) return
  
  const profile = profiles.value[0]
  try {
    const res = await fetch('/api/vpn/connect', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ profile: profile.name })
    })
    const data = await res.json()
    if (data.success) {
      vpnConnected.value = true
      currentProfile.value = profile.name
      alert('VPN подключен!')
      checkStatus()
    } else {
      alert('Ошибка: ' + data.error)
    }
  } catch (e) {
    alert('Ошибка подключения: ' + e)
  }
}

const disconnect = async () => {
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
      currentProfile.value = ''
      profiles.value.forEach(p => p.enabled = false)
      alert('VPN отключен!')
    }
  } catch (e) {
    alert('Ошибка: ' + e)
  }
}

const toggleProfile = async (profile: any) => {
  if (profile.enabled) {
    await disconnect()
  } else {
    profiles.value.forEach(p => p.enabled = false)
    profile.enabled = true
    await quickConnect()
  }
}

const editProfile = (profile: any) => {
  editingProfile.value = profile
  formData.value = { ...profile }
  showAddModal.value = true
}

const deleteProfile = async (index: number) => {
  if (!confirm('Удалить профиль?')) return
  
  profiles.value.splice(index, 1)
  await saveProfiles()
}

const saveProfile = async () => {
  const profile = {
    name: formData.value.name || 'Unnamed',
    protocol: formData.value.protocol,
    enabled: false,
    url: formData.value.url,
    server: formData.value.server,
    port: formData.value.port,
    privateKey: formData.value.privateKey,
    publicKey: formData.value.publicKey,
    psk: formData.value.psk,
    allowedIps: formData.value.allowedIps,
    password: formData.value.password,
    method: formData.value.method,
    configText: formData.value.configText
  }
  
  if (editingProfile.value) {
    const idx = profiles.value.findIndex(p => p.name === editingProfile.value.name)
    if (idx !== -1) profiles.value[idx] = profile
  } else {
    profiles.value.push(profile)
  }
  
  await saveProfiles()
  showAddModal.value = false
  editingProfile.value = null
  resetForm()
}

const saveProfiles = async () => {
  try {
    await fetch('/api/config/save', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        ...JSON.parse(localStorage.getItem('rg_config') || '{}'),
        profiles: profiles.value
      })
    })
  } catch (e) {
    console.error(e)
  }
}

const resetForm = () => {
  formData.value = {
    name: '',
    protocol: 'wireguard',
    url: '',
    server: '',
    port: '',
    privateKey: '',
    publicKey: '',
    psk: '',
    allowedIps: '0.0.0.0/0',
    password: '',
    method: 'aes-256-gcm',
    configText: ''
  }
}

onMounted(() => {
  loadProfiles()
  checkStatus()
  setInterval(checkStatus, 3000)
})
</script>

<style scoped>
.vpn-page {
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

.status-card {
  background: white;
  padding: 1.5rem;
  border-radius: 12px;
  display: flex;
  align-items: center;
  gap: 1rem;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
}

.status-card.connected {
  background: linear-gradient(135deg, #10b981 0%, #059669 100%);
  color: white;
}

.status-icon {
  font-size: 3rem;
}

.status-info h3 {
  font-size: 1.25rem;
  margin-bottom: 0.25rem;
}

.card {
  background: white;
  padding: 1.5rem;
  border-radius: 12px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
}

.card-header h3 {
  font-size: 1.125rem;
}

.empty-state {
  text-align: center;
  padding: 2rem;
  color: #666;
}

.empty-state .hint {
  font-size: 0.875rem;
  color: #999;
}

.profiles-list {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.profile-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1rem;
  background: #f9fafb;
  border-radius: 8px;
  border-left: 3px solid transparent;
}

.profile-item.active {
  background: #d1fae5;
  border-left-color: #10b981;
}

.profile-info h4 {
  font-size: 1rem;
  margin-bottom: 0.25rem;
}

.profile-info .protocol {
  font-size: 0.75rem;
  color: #666;
  text-transform: uppercase;
}

.profile-info .server {
  font-size: 0.875rem;
  color: #999;
}

.profile-actions {
  display: flex;
  gap: 0.5rem;
}

.quick-actions {
  display: flex;
  gap: 1rem;
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

.btn-sm {
  padding: 0.5rem 0.75rem;
  font-size: 0.875rem;
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

.btn-secondary {
  background: #f3f4f6;
  color: #374151;
}

/* Modal */
.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.modal {
  background: white;
  border-radius: 12px;
  width: 90%;
  max-width: 500px;
  max-height: 90vh;
  overflow-y: auto;
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1.5rem;
  border-bottom: 1px solid #e5e7eb;
}

.modal-body {
  padding: 1.5rem;
}

.modal-footer {
  display: flex;
  gap: 1rem;
  justify-content: flex-end;
  padding: 1.5rem;
  border-top: 1px solid #e5e7eb;
}

.btn-close {
  background: none;
  border: none;
  font-size: 1.5rem;
  cursor: pointer;
  color: #666;
}

.form-group {
  margin-bottom: 1rem;
}

.form-group label {
  display: block;
  margin-bottom: 0.5rem;
  font-weight: 500;
}

.form-group input,
.form-group select,
.form-group textarea {
  width: 100%;
  padding: 0.75rem;
  border: 1px solid #d1d5db;
  border-radius: 6px;
  font-size: 0.875rem;
}

.form-group textarea {
  font-family: monospace;
}

.radio-group {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.radio-group label {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  cursor: pointer;
}
</style>
