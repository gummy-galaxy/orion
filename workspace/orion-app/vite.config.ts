import react from '@vitejs/plugin-react'
import { execFileSync, spawn, type ChildProcess } from 'node:child_process'
import { existsSync, rmSync } from 'node:fs'
import { createServer } from 'node:net'
import { fileURLToPath } from 'node:url'
import { defineConfig, type Logger, type Plugin } from 'vite'

const binary = process.env.ORION_BIN || fileURLToPath(new URL('../orion-cli/build/orion', import.meta.url))
const scratchDataDir = fileURLToPath(new URL('.dev-data', import.meta.url))
const seedPlan = fileURLToPath(new URL('fixtures/dev-canvas.json', import.meta.url))

/**
 * The data folder the dev server's CLI serves. A branch's CLI can migrate the folder it touches to a layout the
 * installed app can't read, so it gets a scratch folder unless `ORION_DATA_DIR` names one or `ORION_REAL_DATA=1` asks
 * for the real one.
 */
function getDataDir(logger: Logger): string | undefined {
  if (process.env.ORION_DATA_DIR) return process.env.ORION_DATA_DIR

  if (process.env.ORION_REAL_DATA === '1') {
    logger.warn('[orion] ORION_REAL_DATA=1: serving your real data folder, which this CLI may migrate')

    return undefined
  }

  // The sample plan goes through the CLI, so it lands in whatever layout this branch writes.
  if (!existsSync(scratchDataDir)) {
    try {
      execFileSync(binary, ['apply', seedPlan], {
        env: { ...process.env, ORION_DATA_DIR: scratchDataDir },
        stdio: 'pipe',
      })
    } catch (error) {
      rmSync(scratchDataDir, { recursive: true, force: true })
      logger.error(`[orion] couldn't seed ${scratchDataDir}: ${(error as Error).message}`)
    }
  }

  return scratchDataDir
}

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

      let child: ChildProcess | undefined
      const dataDir = getDataDir(server.config.logger)

      server.config.logger.info(`[orion] data folder: ${dataDir ?? "this platform's default"}`)

      // The server answers only its own address and the dev server's, so it starts once Vite knows its port.
      server.httpServer?.once('listening', () => {
        const address = server.httpServer?.address()
        const devPort = typeof address === 'object' && address ? address.port : server.config.server.port

        child = spawn(
          binary,
          ['server', 'start', '--host', '127.0.0.1', '--port', String(port), '--dev-port', String(devPort)],
          {
            // Development never sends usage data, which also keeps the consent dialog out of dev sessions and PR
            // captures. ORION_TELEMETRY=1 brings it back to try the dialog.
            env: {
              ...process.env,
              ORION_TELEMETRY: process.env.ORION_TELEMETRY ?? '0',
              ...(dataDir ? { ORION_DATA_DIR: dataDir } : {}),
            },
            stdio: ['ignore', 'pipe', 'pipe'],
          },
        )

        // Both streams are read: an unread pipe fills up and stalls the server once it logs enough.
        child.stdout?.on('data', (chunk: Buffer) => server.config.logger.info(`[orion] ${chunk.toString().trim()}`))
        child.stderr?.on('data', (chunk: Buffer) => server.config.logger.error(`[orion] ${chunk.toString().trim()}`))
        child.on('error', (error) => server.config.logger.error(`[orion] ${error.message}`))
      })
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

  // Stories and tests don't read from the server, so they never start a CLI.
  if (process.env.ORION_STORYBOOK === '1' || process.env.VITEST) return { plugins: [react()] }

  const port = await freePort()

  return {
    plugins: [react(), orionServer(port)],
    server: {
      proxy: { '/api': { target: `http://127.0.0.1:${port}`, ws: true } },
      // The server writes its scratch data folder on every change, which isn't app source.
      watch: { ignored: ['**/.dev-data/**'] },
    },
  }
})
