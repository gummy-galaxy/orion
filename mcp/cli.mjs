import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';

const binaryName = process.platform === 'win32' ? 'orion.exe' : 'orion';
const bundledCli = resolve(fileURLToPath(new URL(`../cli/build/${binaryName}`, import.meta.url)));
const maxBuffer = 8 * 1024 * 1024;

export function runOrion(args, { bin = process.env.ORION_BIN || bundledCli, env = process.env, input } = {}) {
  return new Promise((resolvePromise, reject) => {
    const child = spawn(bin, args, { env, stdio: ['pipe', 'pipe', 'pipe'] });
    let stdout = '';
    let stderr = '';
    let settled = false;

    const finish = (callback) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      callback();
    };
    const timer = setTimeout(() => {
      child.kill();
      finish(() => reject(new Error('Orion CLI: timed out')));
    }, 60_000);

    child.stdout.setEncoding('utf8');
    child.stderr.setEncoding('utf8');
    child.stdout.on('data', (chunk) => {
      stdout += chunk;
      if (stdout.length > maxBuffer) child.kill();
    });
    child.stderr.on('data', (chunk) => {
      stderr += chunk;
    });
    child.on('error', (error) => finish(() => reject(new Error(`Orion CLI: ${error.message}`))));
    child.on('close', (code) => {
      finish(() => {
        if (stdout.length > maxBuffer) {
          reject(new Error('Orion CLI: output exceeded 8MB'));
          return;
        }
        const output = stdout.trim();
        if (code !== 0) {
          reject(new Error(`Orion CLI: ${stderr.trim() || output || `exit ${code}`}`));
          return;
        }
        try {
          resolvePromise(JSON.parse(output));
        } catch {
          resolvePromise(output);
        }
      });
    });

    if (input !== undefined) child.stdin.write(input);
    child.stdin.end();
  });
}

export function result(value) {
  return {
    content: [{ type: 'text', text: typeof value === 'string' ? value : JSON.stringify(value) }],
    ...(typeof value === 'object' && value !== null && !Array.isArray(value)
      ? { structuredContent: value }
      : {}),
  };
}
