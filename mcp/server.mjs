import * as z from 'zod/v4';
import { pathToFileURL } from 'node:url';
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { result, runOrion } from './cli.mjs';

async function invoke(name, input) {
  try {
    return result(await runOrion(['mcp', 'call', name], { input: `${JSON.stringify(input)}\n` }));
  } catch (error) {
    return { content: [{ type: 'text', text: error.message }], isError: true };
  }
}

export async function createServer() {
  const server = new McpServer({ name: 'orion', version: '0.1.0' });
  const catalog = await runOrion(['mcp', 'tools']);

  for (const tool of catalog.tools) {
    server.registerTool(tool.name, {
      description: tool.description,
      inputSchema: z.fromJSONSchema(tool.inputSchema),
      ...(tool.annotations ? { annotations: tool.annotations } : {}),
    }, (input) => invoke(tool.name, input));
  }

  return server;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const server = await createServer();
  server.connect(new StdioServerTransport()).catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}
