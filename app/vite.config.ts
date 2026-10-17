import react from '@vitejs/plugin-react'
import { spawn, type ChildProcess } from 'node:child_process'
import { existsSync } from 'node:fs'
import { createServer } from 'node:net'
import { fileURLToPath } from 'node:url'
import { defineConfig, type Plugin } from 'vite'

const binary = process.env.ORION_BIN || fileURLToPath(new URL('../cli/build/orion', import.meta.url))

function freePort(): Promise<number> {
  return new Promise((resolve, reject) => {
    const probe = createServer()

    probe.once('error', reject)
    probe.listen(0, '127.0.0.1', () => {
      const address = probe.address()
      const port = typeof address === 'object' && address ? address.port : 5198

      probe.close(() => resolve(port))
    })
  })
}

function orionServer(port: number): Plugin {
  return {
    name: 'orion-server',
    apply: 'serve',
    configureServer(server) {
      if (!existsSync(binary)) {
        server.config.logger.warn('Build the CLI: cd cli && lute run build')

        return
      }

      let child: ChildProcess | undefined = spawn(binary, ['server', 'start', '--host', '127.0.0.1', '--port', String(port)], {
        env: process.env,
        stdio: ['ignore', 'pipe', 'pipe'],
      })

      // Both streams are read: an unread pipe fills up and stalls the server once it logs enough.
      child.stdout?.on('data', (chunk: Buffer) => server.config.logger.info(`[orion] ${chunk.toString().trim()}`))
      child.stderr?.on('data', (chunk: Buffer) => server.config.logger.error(`[orion] ${chunk.toString().trim()}`))
      child.on('error', (error) => server.config.logger.error(`[orion] ${error.message}`))
      server.httpServer?.once('close', () => {
        child?.kill()
        child = undefined
      })
    },
  }
}

// https://vite.dev/config/
export default defineConfig(async ({ command }) => {
  // The desktop build lists these licenses on its Acknowledgements page.
  if (command === 'build') return { plugins: [react()], build: { license: { fileName: '.vite/licenses.json' } } }

  if (process.env.ORION_STORYBOOK === '1') return { plugins: [react()] }

  const port = await freePort()

  return {
    plugins: [react(), orionServer(port)],
    server: {
      proxy: { '/api': { target: `http://127.0.0.1:${port}`, ws: true } },
    },
  }
})
