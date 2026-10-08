import * as z from 'zod/v4';
import { pathToFileURL } from 'node:url';
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { call, option, workspaceOption } from './cli.mjs';

const workspace = z.string().regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/).optional()
  .describe('Workspace name. Omit to use the workspace selected in Orion.');
const id = z.string().min(1).describe('Orion item or group ID');
const status = z.enum(['todo', 'active', 'review', 'blocked', 'deferred', 'done']);

function register(server, name, config, args) {
  server.registerTool(name, config, async (input) => {
    try {
      return await call(args(input));
    } catch (error) {
      return { content: [{ type: 'text', text: error.message }], isError: true };
    }
  });
}

export function createServer() {
  const server = new McpServer({ name: 'orion', version: '0.1.0' });

  register(server, 'orion_workspaces', {
    description: 'List Orion workspaces and the active workspace.',
    inputSchema: {},
    annotations: { readOnlyHint: true },
  }, () => ['workspace', 'list', '--json']);

  register(server, 'orion_inspect', {
    description: 'Read the canvas: list items, ready work, groups, PR matches, or one item/group.',
    inputSchema: {
      view: z.enum(['list', 'ready', 'groups', 'matches', 'show']),
      workspace,
      id: id.optional().describe('Required for show.'),
      group: id.optional().describe('Limit list to descendants of a group.'),
      all: z.boolean().optional().describe('Include completed items in list.'),
    },
    annotations: { readOnlyHint: true },
  }, ({ view, workspace, id, group, all }) => {
    if (view === 'show' && !id) throw new Error('id is required for show');
    return [view, ...(view === 'show' ? [id] : []),
      ...(view === 'list' ? [...option('group', group), ...(all ? ['--all'] : [])] : []),
      ...workspaceOption(workspace), '--json'];
  });

  register(server, 'orion_add_item', {
    description: 'Add a work item to the canvas.',
    inputSchema: {
      title: z.string().min(1), workspace, group: id.optional(),
      repo: z.string().optional(), pr: z.number().int().positive().optional(),
      status: status.optional(),
    },
  }, ({ title, workspace, group, repo, pr, status }) =>
    ['add', title, ...workspaceOption(workspace), ...option('group', group),
      ...option('repo', repo), ...option('pr', pr), ...option('status', status), '--json']);

  register(server, 'orion_update_item', {
    description: 'Change fields on an existing Orion item or group.',
    inputSchema: {
      id, workspace, label: z.string().optional(), status: status.optional(),
      who: z.enum(['you', 'review', 'ci', '']).optional(), note: z.string().optional(),
      repo: z.string().optional(), pr: z.number().int().positive().optional(),
    },
  }, ({ id, workspace, label, status, who, note, repo, pr }) =>
    ['set', id, ...workspaceOption(workspace), ...option('label', label),
      ...option('status', status), ...option('who', who), ...option('note', note),
      ...option('repo', repo), ...option('pr', pr), '--json']);

  register(server, 'orion_add_note', {
    description: 'Add a canvas note, optionally inside a group or a dependency link.',
    inputSchema: {
      text: z.string().min(1), workspace, group: id.optional(),
      after: id.optional(), before: id.optional(),
    },
  }, ({ text, workspace, group, after, before }) =>
    ['note', text, ...workspaceOption(workspace), ...option('group', group),
      ...option('after', after), ...option('before', before), '--json']);

  register(server, 'orion_images', {
    description: 'List image nodes in an Orion workspace.',
    inputSchema: { workspace },
    annotations: { readOnlyHint: true },
  }, ({ workspace }) => ['media', 'list', ...workspaceOption(workspace), '--json']);

  register(server, 'orion_add_image', {
    description: 'Import a local PNG, JPEG, GIF, or WebP file as an image node. The CLI copies it into the workspace assets folder.',
    inputSchema: {
      path: z.string().min(1).describe('Absolute path to a local image file.'),
      label: z.string().min(1).optional(), workspace, group: id.optional(),
    },
  }, ({ path, label, workspace, group }) =>
    ['media', 'insert', path, ...option('label', label), ...option('group', group),
      ...workspaceOption(workspace), '--json']);

  register(server, 'orion_link', {
    description: 'Connect two items, optionally as a related link that does not block work.',
    inputSchema: { from: id, to: id, workspace, related: z.boolean().optional() },
  }, ({ from, to, workspace, related }) =>
    ['link', from, to, ...workspaceOption(workspace), ...(related ? ['--related'] : [])]);

  register(server, 'orion_unlink', {
    description: 'Remove a dependency or related link between two items.',
    inputSchema: { from: id, to: id, workspace },
  }, ({ from, to, workspace }) => ['unlink', from, to, ...workspaceOption(workspace)]);

  register(server, 'orion_group', {
    description: 'Wrap existing items in a new group.',
    inputSchema: {
      label: z.string().min(1), items: z.array(id).min(1), workspace,
    },
  }, ({ label, items, workspace }) =>
    ['group', label, '--items', items.join(','), ...workspaceOption(workspace), '--json']);

  register(server, 'orion_move', {
    description: 'Move an item into a group or to the top level.',
    inputSchema: { id, workspace, group: id.optional() },
  }, ({ id, workspace, group }) =>
    ['move', id, ...workspaceOption(workspace), ...(group ? ['--to', group] : ['--top'])]);

  register(server, 'orion_remove', {
    description: 'Delete an item or group from the canvas.',
    inputSchema: { id, workspace },
    annotations: { destructiveHint: true },
  }, ({ id, workspace }) => ['remove', id, ...workspaceOption(workspace)]);

  register(server, 'orion_create_workspace', {
    description: 'Create an Orion workspace.',
    inputSchema: {
      name: z.string().regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/),
      label: z.string().optional(), owner: z.string().optional(),
    },
  }, ({ name, label, owner }) =>
    ['workspace', 'create', name, ...option('label', label), ...option('owner', owner)]);

  register(server, 'orion_select_workspace', {
    description: 'Set the active Orion workspace shown by the app.',
    inputSchema: { name: z.string().regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/) },
  }, ({ name }) => ['workspace', 'use', name]);

  register(server, 'orion_sync', {
    description: 'Refresh pull request cards from GitHub. Discovery adds open authored PRs to Inbox when requested.',
    inputSchema: {
      workspace, dryRun: z.boolean().optional(), discover: z.boolean().optional(),
    },
    annotations: { openWorldHint: true },
  }, ({ workspace, dryRun, discover }) =>
    ['sync', ...workspaceOption(workspace), ...(dryRun ? ['--dry-run'] : []),
      ...(discover ? ['--discover'] : []), '--json']);

  return server;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const server = createServer();
  server.connect(new StdioServerTransport()).catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}
