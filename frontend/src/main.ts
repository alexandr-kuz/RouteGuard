import { createApp } from 'vue'
import { createI18n } from 'vue-i18n'
import App from './App.vue'
import ru from './locales/ru.json'

const i18n = createI18n({
  legacy: false,
  locale: 'ru',
  fallbackLocale: 'ru',
  messages: {
    ru
  }
})

const app = createApp(App)

app.use(i18n)
app.mount('#app')
