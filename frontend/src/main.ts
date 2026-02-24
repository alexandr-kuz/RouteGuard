import { createApp } from 'vue'
import { createRouter, createWebHistory } from 'vue-router'
import { createI18n } from 'vue-i18n'

import App from './App.vue'
import Login from './views/Login.vue'
import Dashboard from './views/Dashboard.vue'
import VPN from './views/VPN.vue'
import Routing from './views/Routing.vue'
import DNS from './views/DNS.vue'
import DPI from './views/DPI.vue'
import Settings from './views/Settings.vue'
import ru from './locales/ru.json'

// i18n
const i18n = createI18n({
  legacy: false,
  locale: 'ru',
  fallbackLocale: 'ru',
  messages: { ru }
})

// Router
const routes = [
  { path: '/login', component: Login },
  { path: '/', component: Dashboard, meta: { requiresAuth: true } },
  { path: '/vpn', component: VPN, meta: { requiresAuth: true } },
  { path: '/routing', component: Routing, meta: { requiresAuth: true } },
  { path: '/dns', component: DNS, meta: { requiresAuth: true } },
  { path: '/dpi', component: DPI, meta: { requiresAuth: true } },
  { path: '/settings', component: Settings, meta: { requiresAuth: true } }
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

// Auth guard
router.beforeEach((to, from, next) => {
  const token = localStorage.getItem('rg_token')
  
  if (to.meta.requiresAuth && !token) {
    next('/login')
  } else if (to.path === '/login' && token) {
    next('/')
  } else {
    next()
  }
})

// App
const app = createApp(App)
app.use(i18n)
app.use(router)
app.mount('#app')
