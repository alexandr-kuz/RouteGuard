<template>
  <div class="login-page">
    <div class="login-card">
      <h1>🛡️ RouteGuard</h1>
      <p class="subtitle">Введите токен для доступа</p>
      
      <form @submit.prevent="login">
        <div class="form-group">
          <input 
            v-model="token" 
            type="text" 
            placeholder="API токен"
            required
          />
        </div>
        <button type="submit" class="btn btn-primary" :disabled="loading">
          {{ loading ? 'Проверка...' : 'Войти' }}
        </button>
      </form>
      
      <p v-if="error" class="error">{{ error }}</p>
      
      <div class="hint">
        <p>Токен можно найти в файле:</p>
        <code>/opt/etc/routeguard/.api_token</code>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'

const router = useRouter()
const token = ref('')
const loading = ref(false)
const error = ref('')

const login = async () => {
  if (!token.value.trim()) {
    error.value = 'Введите токен'
    return
  }
  
  loading.value = true
  error.value = ''
  
  try {
    const res = await fetch('/api/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token: token.value })
    })
    
    const data = await res.json()
    
    if (data.success) {
      localStorage.setItem('rg_token', token.value)
      router.push('/')
    } else {
      error.value = data.error || 'Неверный токен'
    }
  } catch (e) {
    error.value = 'Ошибка подключения: ' + e
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.login-page {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
}

.login-card {
  background: white;
  padding: 2.5rem;
  border-radius: 16px;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
  width: 100%;
  max-width: 400px;
  text-align: center;
}

.login-card h1 {
  font-size: 2rem;
  margin-bottom: 0.5rem;
}

.subtitle {
  color: #666;
  margin-bottom: 2rem;
}

.form-group {
  margin-bottom: 1.5rem;
}

.form-group input {
  width: 100%;
  padding: 0.875rem 1rem;
  border: 2px solid #e5e7eb;
  border-radius: 8px;
  font-size: 1rem;
  transition: border-color 0.2s;
}

.form-group input:focus {
  outline: none;
  border-color: #4f46e5;
}

.btn {
  width: 100%;
  padding: 0.875rem 1.5rem;
  border: none;
  border-radius: 8px;
  font-size: 1rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
}

.btn:disabled {
  opacity: 0.7;
  cursor: not-allowed;
}

.btn-primary {
  background: #4f46e5;
  color: white;
}

.btn-primary:hover:not(:disabled) {
  background: #4338ca;
}

.error {
  color: #ef4444;
  margin-top: 1rem;
  font-size: 0.875rem;
}

.hint {
  margin-top: 2rem;
  padding-top: 1.5rem;
  border-top: 1px solid #e5e7eb;
  font-size: 0.875rem;
  color: #666;
}

.hint code {
  display: block;
  margin-top: 0.5rem;
  padding: 0.5rem;
  background: #f3f4f6;
  border-radius: 4px;
  font-family: monospace;
  font-size: 0.75rem;
}
</style>
