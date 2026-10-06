import { execFile } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';
import { promisify } from 'node:util';

const execFileAsync = promisify(execFile);
const bundledCli = resolve(fileURLToPath(new URL('../cli/build/orion', import.meta.url)));

export function option(name, value) {
  return value === undefined || value === null ? [] : [`--${name}`, String(value)];
}

export function workspaceOption(workspace) {
  return option('workspace', workspace);
}

export async function runOrion(args, { bin = process.env.ORION_BIN || bundledCli, env = process.env } = {}) {
  try {
    const { stdout } = await execFileAsync(bin, args, {
      env,
      encoding: 'utf8',
      maxBuffer: 8 * 1024 * 1024,
      timeout: 60_000,
    });
    const output = stdout.trim();
    try {
      return JSON.parse(output);
    } catch {
      return output;
    }
  } catch (error) {
    const message = error.stderr?.trim() || error.stdout?.trim() || error.message;
    throw new Error(`Orion CLI: ${message}`);
  }
}

export function result(value) {
  return {
    content: [{ type: 'text', text: typeof value === 'string' ? value : JSON.stringify(value) }],
    ...(typeof value === 'object' && value !== null && !Array.isArray(value)
      ? { structuredContent: value }
      : {}),
  };
}

export async function call(args) {
  try {
    return result(await runOrion(args));
  } catch (error) {
    return { content: [{ type: 'text', text: error.message }], isError: true };
  }
}
