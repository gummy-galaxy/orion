local json = require("@std/json")

local appendFlag = require("@root/cli/mcp/catalog/appendFlag")
local appendOption = require("@root/cli/mcp/catalog/appendOption")
local fieldValues = require("@root/fieldValues")
local getRequiredString = require("@root/cli/mcp/catalog/getRequiredString")
local getStringField = require("@root/getStringField")
local mcpTypes = require("@root/cli/mcp/types")

type Field = mcpTypes.Field
type Tool = mcpTypes.Tool

local VIEWS = { "list", "ready", "groups", "matches", "show" }

-- The CLI command each view reads with. The view names stay as the MCP enum values.
local VIEW_COMMANDS: { [string]: { string } } = {
	list = { "card", "list" },
	ready = { "next" },
	groups = { "group", "list" },
	matches = { "source", "matches" },
	show = { "node", "show" },
}

local REF_DESCRIPTION =
	"Outside work to attach: a GitHub or Jira URL, source:key such as jira:ABC-1, or branch:owner/name@branch."
local DEPRECATED_REPO = "Deprecated: with pr, use ref with the pull request URL instead."
local DEPRECATED_PR = "Deprecated: use ref with the pull request URL instead."
local SELECTOR_DESCRIPTION =
	'An id, or a selector such as label:"Extract slider", ref:jira:ABC-12, or pr:86 that must match exactly one item.'
local NOTE_STYLE =
	"Write it as a plain-language summary: Markdown for structure, code formatting for code, file paths, and identifiers, and no pull request or issue links in the text. Attach those as refs on a card."
local NOTE_DESCRIPTION = "Replaces the whole note. " .. NOTE_STYLE

local WHO = table.clone(fieldValues.who)
table.insert(WHO, "")

local shapeField: Field = {
	name = "shape",
	kind = "enum",
	values = fieldValues.shapes,
	description = "How a component is drawn. Giving a shape makes the item a component.",
	at = "option",
}

local colorField: Field = {
	name = "color",
	kind = "enum",
	values = fieldValues.colors,
	description = "A component's tint. Components take their nearest group's tint unless they set their own.",
	at = "option",
}

local kindField: Field = {
	name = "kind",
	kind = "enum",
	values = fieldValues.kinds,
	description = "step for ordinary work, gate for a milestone that's done once everything it waits on is, or component for a part of a system diagram that isn't work.",
	at = "option",
}

local workspaceField: Field = {
	name = "workspace",
	kind = "workspace",
	description = "Canvas name. Omit to use the canvas selected in Orion.",
	at = "option",
	flag = "canvas",
}

-- Each view is its own read command, and only some take an id or a group.
local function buildInspectArgv(arguments: json.Object): { string }
	local view = getRequiredString(arguments, "view")
	local argv = table.clone(assert(VIEW_COMMANDS[view], `unknown view: {view}`))

	if view == "show" then
		table.insert(argv, getRequiredString(arguments, "id"))
	elseif view == "list" then
		appendOption(argv, "group", arguments.group)
		appendFlag(argv, "all", arguments.all)
	end

	appendOption(argv, "canvas", arguments.workspace)
	table.insert(argv, "--json")
	return argv
end

-- Workspace names are optional when a label is given, so the name is passed only when present.
local function buildCreateWorkspaceArgv(arguments: json.Object): { string }
	local argv = { "canvas", "create" }
	local name = getStringField(arguments.name)

	if name then
		table.insert(argv, name)
	end

	appendOption(argv, "label", arguments.label)
	return argv
end

-- Without a group, the item moves to the top level.
local function buildMoveArgv(arguments: json.Object): { string }
	local argv = { "node", "move", getRequiredString(arguments, "id") }
	local group = getStringField(arguments.group)

	if group then
		table.insert(argv, "--to")
		table.insert(argv, group)
	else
		table.insert(argv, "--top")
	end

	appendOption(argv, "canvas", arguments.workspace)
	return argv
end

-- Refs are one list argument, which the CLI takes as trailing positionals.
local function buildImportArgv(arguments: json.Object): { string }
	local argv = { "card", "import" }
	local refs = json.asArray(arguments.refs) or {}

	for _, ref in refs do
		assert(type(ref) == "string" and ref ~= "", "refs must be a list of strings")
		table.insert(argv, ref)
	end

	appendOption(argv, "group", arguments.group)
	appendFlag(argv, "dry-run", arguments.dryRun)
	appendOption(argv, "canvas", arguments.workspace)
	table.insert(argv, "--json")
	return argv
end

-- Every tool the MCP server offers, in the order tools/list reports them. Tools map their
-- fields onto a CLI command, and those that need more than that supply their own build.
local tools: { Tool } = {
	{
		name = "orion_workspaces",
		description = "List Orion canvases and the active canvas, or the archived ones.",
		annotations = { readOnlyHint = true },
		command = { "canvas", "list" },
		json = true,
		fields = {
			{
				name = "archived",
				kind = "boolean",
				description = "List archived canvases instead.",
				at = "flag",
				flag = "archived",
			},
		},
	},
	{
		name = "orion_inspect",
		description = "Read the canvas: list items, ready work, groups, PR matches, or one item/group.",
		annotations = { readOnlyHint = true },
		command = {},
		fields = {
			{
				name = "view",
				kind = "enum",
				required = true,
				values = VIEWS,
				at = "positional",
			},
			workspaceField,
			{
				name = "id",
				kind = "id",
				description = `Required for show. {SELECTOR_DESCRIPTION}`,
				at = "option",
			},
			{
				name = "group",
				kind = "id",
				description = "Limit list to descendants of a group.",
				at = "option",
			},
			{
				name = "all",
				kind = "boolean",
				description = "Include completed items in list.",
				at = "flag",
			},
		},
		build = buildInspectArgv,
	},
	{
		name = "orion_find",
		description = 'Find cards and groups whose label, note, or refs contain text, label matches first. Returns the total and up to limit matches with their ids. Use an id or a selector such as label:"..." or ref:... to act on one.',
		annotations = { readOnlyHint = true },
		command = { "node", "find" },
		json = true,
		fields = {
			{
				name = "text",
				kind = "string",
				required = true,
				minLength = 1,
				description = "Text to find, matched case-insensitively.",
				at = "positional",
			},
			workspaceField,
			{ name = "limit", kind = "int", description = "Most matches to return. Defaults to 20.", at = "option" },
			{
				name = "allCanvases",
				kind = "boolean",
				description = "Search every canvas, not only the selected one.",
				at = "flag",
				flag = "all-canvases",
			},
		},
	},
	{
		name = "orion_add_item",
		description = "Add a work item, or a component for a system diagram, to the canvas.",
		command = { "card", "add" },
		json = true,
		fields = {
			{ name = "title", kind = "string", required = true, minLength = 1, at = "positional" },
			workspaceField,
			{ name = "group", kind = "id", at = "option" },
			kindField,
			shapeField,
			colorField,
			{ name = "repo", kind = "string", description = DEPRECATED_REPO, at = "option" },
			{ name = "pr", kind = "int", description = DEPRECATED_PR, at = "option" },
			{ name = "ref", kind = "string", description = REF_DESCRIPTION, at = "option" },
			{ name = "status", kind = "enum", values = fieldValues.statuses, at = "option" },
			{ name = "note", kind = "string", at = "option" },
		},
	},
	{
		name = "orion_update_item",
		description = "Change fields on an existing Orion card.",
		command = { "card", "set" },
		json = true,
		fields = {
			{ name = "id", kind = "id", required = true, description = SELECTOR_DESCRIPTION, at = "positional" },
			workspaceField,
			{ name = "label", kind = "string", at = "option" },
			{ name = "status", kind = "enum", values = fieldValues.statuses, at = "option" },
			{
				name = "who",
				kind = "enum",
				values = WHO,
				description = "Whose move: you, review, or ci. Empty clears it.",
				at = "option",
			},
			{ name = "note", kind = "string", description = NOTE_DESCRIPTION, at = "option" },
			kindField,
			shapeField,
			colorField,
			{ name = "repo", kind = "string", description = DEPRECATED_REPO, at = "option" },
			{ name = "pr", kind = "int", description = DEPRECATED_PR, at = "option" },
			{ name = "ref", kind = "string", description = REF_DESCRIPTION, at = "option" },
		},
	},
	{
		name = "orion_add_note",
		description = "Add a canvas note, optionally inside a group or a dependency link. " .. NOTE_STYLE,
		command = { "note", "add" },
		json = true,
		fields = {
			{ name = "text", kind = "string", required = true, minLength = 1, at = "positional" },
			workspaceField,
			{ name = "group", kind = "id", at = "option" },
			{ name = "after", kind = "id", at = "option" },
			{ name = "before", kind = "id", at = "option" },
		},
	},
	{
		name = "orion_images",
		description = "List image nodes in an Orion canvas.",
		annotations = { readOnlyHint = true },
		command = { "media", "list" },
		json = true,
		fields = { workspaceField },
	},
	{
		name = "orion_add_image",
		description = "Import a local PNG, JPEG, GIF, or WebP file as an image node. The CLI copies it into the canvas assets folder.",
		command = { "media", "insert" },
		json = true,
		fields = {
			{
				name = "path",
				kind = "string",
				required = true,
				minLength = 1,
				description = "Absolute path to a local image file.",
				at = "positional",
			},
			{ name = "label", kind = "string", minLength = 1, at = "option" },
			workspaceField,
			{ name = "group", kind = "id", at = "option" },
		},
	},
	{
		name = "orion_link",
		description = "Connect two items, optionally as a related link that does not block work. Linking an already linked pair updates that link.",
		command = { "link", "add" },
		fields = {
			{ name = "from", kind = "id", required = true, description = SELECTOR_DESCRIPTION, at = "positional" },
			{ name = "to", kind = "id", required = true, description = SELECTOR_DESCRIPTION, at = "positional" },
			workspaceField,
			{ name = "related", kind = "boolean", at = "flag", flag = "related" },
			{
				name = "label",
				kind = "string",
				description = "What the link carries, such as HTTP or WebSocket. Empty clears it.",
				at = "option",
			},
		},
	},
	{
		name = "orion_unlink",
		description = "Remove a dependency or related link between two items.",
		command = { "link", "remove" },
		fields = {
			{ name = "from", kind = "id", required = true, description = SELECTOR_DESCRIPTION, at = "positional" },
			{ name = "to", kind = "id", required = true, description = SELECTOR_DESCRIPTION, at = "positional" },
			workspaceField,
		},
	},
	{
		name = "orion_group",
		description = "Wrap existing items in a new group.",
		command = { "group", "add" },
		json = true,
		fields = {
			{ name = "label", kind = "string", required = true, minLength = 1, at = "positional" },
			{ name = "items", kind = "strings", required = true, at = "csv", flag = "items" },
			workspaceField,
		},
	},
	{
		name = "orion_move",
		description = "Move an item into a group or to the top level.",
		command = { "node", "move" },
		fields = {
			{ name = "id", kind = "id", required = true, description = SELECTOR_DESCRIPTION, at = "positional" },
			workspaceField,
			{ name = "group", kind = "id", at = "option" },
		},
		build = buildMoveArgv,
	},
	{
		name = "orion_remove",
		description = "Delete an item from the canvas. Use orion_remove_group for a group.",
		annotations = { destructiveHint = true },
		command = { "node", "remove" },
		fields = {
			{ name = "id", kind = "id", required = true, description = SELECTOR_DESCRIPTION, at = "positional" },
			workspaceField,
		},
	},
	{
		name = "orion_remove_group",
		description = "Delete a group and everything inside it. A dry run lists what would go.",
		annotations = { destructiveHint = true },
		command = { "group", "remove" },
		json = true,
		fields = {
			{ name = "id", kind = "id", required = true, at = "positional" },
			workspaceField,
			{ name = "dryRun", kind = "boolean", at = "flag", flag = "dry-run" },
		},
	},
	{
		name = "orion_remove_ref",
		description = "Take a GitHub, Jira, or branch ref off an item. Name it by the key orion_inspect lists, or by its URL.",
		command = { "ref", "remove" },
		json = true,
		fields = {
			{ name = "id", kind = "id", required = true, description = SELECTOR_DESCRIPTION, at = "positional" },
			{ name = "ref", kind = "string", required = true, minLength = 1, at = "positional" },
			workspaceField,
		},
	},
	{
		name = "orion_create_workspace",
		description = "Create an Orion canvas. Without a name, one is derived from the label.",
		command = { "canvas", "create" },
		fields = {
			{
				name = "name",
				kind = "workspace",
				description = "Canvas name. Omit it to derive one from label.",
				at = "positional",
			},
			{
				name = "label",
				kind = "string",
				description = "Display label. Required when name is omitted.",
				at = "option",
			},
		},
		build = buildCreateWorkspaceArgv,
	},
	{
		name = "orion_rename_workspace",
		description = "Change a canvas's display label. The name and folder stay the same.",
		command = { "canvas", "rename" },
		fields = {
			{ name = "name", kind = "workspace", required = true, at = "positional" },
			{ name = "label", kind = "string", required = true, minLength = 1, at = "positional" },
		},
	},
	{
		name = "orion_archive_workspace",
		description = "Archive a canvas so it leaves the canvas list. Its data stays in place. The active canvas can't be archived.",
		command = { "canvas", "archive" },
		fields = {
			{ name = "name", kind = "workspace", required = true, at = "positional" },
		},
	},
	{
		name = "orion_restore_workspace",
		description = "Restore an archived Orion canvas with its data.",
		command = { "canvas", "restore" },
		fields = {
			{ name = "name", kind = "workspace", required = true, at = "positional" },
		},
	},
	{
		name = "orion_select_workspace",
		description = "Set the active Orion canvas shown by the app.",
		command = { "canvas", "use" },
		fields = {
			{ name = "name", kind = "workspace", required = true, at = "positional" },
		},
	},
	{
		name = "orion_ingest",
		description = "Import work from the canvas's configured sources into Unsorted, and refresh the cards they track, such as pull request states from GitHub.",
		annotations = { openWorldHint = true },
		command = { "ingest" },
		json = true,
		fields = {
			workspaceField,
			{ name = "dryRun", kind = "boolean", at = "flag", flag = "dry-run" },
			{ name = "source", kind = "string", at = "option" },
		},
	},
	{
		name = "orion_sync",
		description = "Deprecated: use orion_ingest. Refresh pull request cards from GitHub. Discovery adds open authored PRs to Inbox when requested.",
		annotations = { openWorldHint = true },
		command = { "sync" },
		json = true,
		fields = {
			workspaceField,
			{ name = "dryRun", kind = "boolean", at = "flag", flag = "dry-run" },
			{ name = "discover", kind = "boolean", at = "flag", flag = "discover" },
		},
	},
	{
		name = "orion_import",
		description = "Add a card for each GitHub or Jira URL, or source:key, in one step. Refs already on the canvas are skipped. Refs that don't resolve are reported and skipped, and the call fails if any did.",
		annotations = { openWorldHint = true },
		command = { "card", "import" },
		json = true,
		build = buildImportArgv,
		fields = {
			workspaceField,
			{ name = "refs", kind = "strings", required = true, at = "positional" },
			{ name = "group", kind = "id", at = "option" },
			{ name = "dryRun", kind = "boolean", at = "flag", flag = "dry-run" },
		},
	},
}

return table.freeze(tools)
