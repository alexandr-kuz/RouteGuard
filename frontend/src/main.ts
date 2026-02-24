import { createApp } from 'vue'
import { createRouter, createWebHistory } from 'vue-router'
import { createI18n } from 'vue-i18n'

import App from './App.vue'
import Dashboard from './views/Dashboard.vue'
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
  { path: '/', component: Dashboard },
  { path: '/vpn', component: () => import('./views/VPN.vue') },
  { path: '/routing', component: () => import('./views/Routing.vue') },
  { path: '/dns', component: () => import('./views/DNS.vue') },
  { path: '/dpi', component: () => import('./views/DPI.vue') },
  { path: '/settings', component: () => import('./views/Settings.vue') }
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

// App
const app = createApp(App)
app.use(i18n)
app.use(router)
app.mount('#app')
