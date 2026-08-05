import { createApp } from 'vue'
import { createPinia } from 'pinia'
import ElementPlus from 'element-plus'
import zhCn from 'element-plus/es/locale/lang/zh-cn'
import 'element-plus/dist/index.css'
import * as ElIcons from '@element-plus/icons-vue'
import App from './App.vue'
import router from './router'
import './assets/global.css'

const app = createApp(App)
const pinia = createPinia()

for (const [name, component] of Object.entries(ElIcons)) {
  app.component(name, component)
}

app.use(pinia)
app.use(router)
app.use(ElementPlus, { locale: zhCn, size: 'default' })

app.mount('#app')
