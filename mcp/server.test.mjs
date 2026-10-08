import assert from 'node:assert/strict';
import { mkdtemp, rm, access, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { test } from 'node:test';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';

const bin = process.env.ORION_TEST_BIN;

test('MCP tools round-trip through the Orion CLI and workspace storage', { skip: !bin }, async () => {
  const dataDir = await mkdtemp(join(tmpdir(), 'orion-mcp-test-'));
  const client = new Client({ name: 'orion-test', version: '1.0.0' });
  const transport = new StdioClientTransport({
    command: process.execPath,
    args: [resolve('server.mjs')],
    env: { ...process.env, ORION_BIN: bin, ORION_DATA_DIR: dataDir },
  });
  try {
    await client.connect(transport);
    const tools = (await client.listTools()).tools;
    const names = tools.map((tool) => tool.name);
    assert.ok(names.includes('orion_inspect'));
    assert.ok(names.includes('orion_create_workspace'));
    assert.ok(names.includes('orion_add_image'));
    const addItem = tools.find((tool) => tool.name === 'orion_add_item');
    assert.ok(addItem.inputSchema.required.includes('title'));

    let response = await client.callTool({ name: 'orion_create_workspace', arguments: {
      name: 'sample', label: 'Sample', owner: 'vocksel',
    } });
    assert.equal(response.isError, undefined);

    response = await client.callTool({ name: 'orion_add_item', arguments: {
      title: 'MCP smoke test', workspace: 'sample',
    } });
    assert.equal(response.isError, undefined);
    const added = JSON.parse(response.content[0].text);
    assert.equal(added.label, 'MCP smoke test');

    response = await client.callTool({ name: 'orion_inspect', arguments: {
      view: 'show', workspace: 'sample', id: added.id,
    } });
    assert.equal(response.isError, undefined);
    assert.match(response.content[0].text, /MCP smoke test/);

    const imageFile = join(dataDir, 'sample.png');
    await writeFile(imageFile, Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/Zc8AAAAASUVORK5CYII=', 'base64'));
    response = await client.callTool({ name: 'orion_add_image', arguments: {
      path: imageFile, label: 'Sample image', workspace: 'sample',
    } });
    assert.equal(response.isError, undefined);
    const image = JSON.parse(response.content[0].text);
    assert.equal(image.label, 'Sample image');
    response = await client.callTool({ name: 'orion_images', arguments: { workspace: 'sample' } });
    assert.equal(response.isError, undefined);
    assert.equal(JSON.parse(response.content[0].text)[0].id, image.id);

    const unexpectedFile = join(dataDir, 'unexpected');
    response = await client.callTool({ name: 'orion_add_note', arguments: {
      text: `Literal $(touch ${unexpectedFile})`, workspace: 'sample',
    } });
    assert.equal(response.isError, undefined);
    await assert.rejects(access(unexpectedFile));

    response = await client.callTool({ name: 'orion_inspect', arguments: {
      view: 'show', workspace: 'sample', id: 'missing',
    } });
    assert.equal(response.isError, true);
  } finally {
    await client.close();
    await rm(dataDir, { recursive: true, force: true });
  }
});
