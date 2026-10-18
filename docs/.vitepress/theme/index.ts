import DefaultTheme from 'vitepress/theme'
import type { Theme } from 'vitepress'
import Story from './components/Story.vue'
import './vibrant.css'

export default {
  extends: DefaultTheme,
  enhanceApp({ app }) {
    app.component('Story', Story)
  },
} satisfies Theme
