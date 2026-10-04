import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'
import { orionStore } from './server/store.ts'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react(), orionStore()],
})
