import { createServer } from 'node:http'
import { readFileSync, writeFileSync, existsSync } from 'node:fs'
import { join, extname } from 'node:path'
const root = process.cwd()
const types = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.png': 'image/png' }
createServer(async (req, res) => {
  const url = new URL(req.url, 'http://x')
  if (req.method === 'POST' && url.pathname === '/save') {
    const chunks = []; for await (const c of req) chunks.push(c)
    const name = url.searchParams.get('name').replace(/[^a-z0-9-]/gi, '')
    writeFileSync(join(root, `${name}.png`), Buffer.from(Buffer.concat(chunks).toString().split(',')[1], 'base64'))
    res.end('ok'); return
  }
  const file = join(root, url.pathname === '/' ? 'index.html' : url.pathname)
  if (!existsSync(file)) { res.statusCode = 404; res.end(); return }
  res.setHeader('content-type', types[extname(file)] ?? 'application/octet-stream')
  res.end(readFileSync(file))
}).listen(5230)
