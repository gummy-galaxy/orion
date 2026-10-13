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

local REF_DESCRIPTION =
	"Outside work to attach: a GitHub or Jira URL, source:key such as jira:ABC-1, or branch:owner/name@branch."
local DEPRECATED_REPO = "Deprecated: with pr, use ref with the pull request URL instead."
local DEPRECATED_PR = "Deprecated: use ref with the pull request URL instead."

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
	description = "A component's or group's tint. Components take their nearest group's tint unless they set their own.",
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
	description = "Workspace name. Omit to use the workspace selected in Orion.",
	at = "option",
	flag = "workspace",
}

-- Each view is its own read command, and only some take an id or a group.
local function buildInspectArgv(arguments: json.Object): { string }
	local view = getRequiredString(arguments, "view")
	local argv = { view }

	if view == "show" then
		table.insert(argv, getRequiredString(arguments, "id"))
	elseif view == "list" then
		appendOption(argv, "group", arguments.group)
		appendFlag(argv, "all", arguments.all)
	end

	appendOption(argv, "workspace", arguments.workspace)
	table.insert(argv, "--json")
	return argv
end

-- Workspace names are optional when a label is given, so the name is passed only when present.
local function buildCreateWorkspaceArgv(arguments: json.Object): { string }
	local argv = { "workspace", "create" }
	local name = getStringField(arguments.name)

	if name then
		table.insert(argv, name)
	end

	appendOption(argv, "label", arguments.label)
	return argv
end

-- Without a group, the item moves to the top level.
local function buildMoveArgv(arguments: json.Object): { string }
	local argv = { "move", getRequiredString(arguments, "id") }
	local group = getStringField(arguments.group)

	if group then
		table.insert(argv, "--to")
		table.insert(argv, group)
	else
		table.insert(argv, "--top")
	end

	appendOption(argv, "workspace", arguments.workspace)
	return argv
end

-- Refs are one list argument, which the CLI takes as trailing positionals.
local function buildImportArgv(arguments: json.Object): { string }
	local argv = { "import" }
	local refs = json.asArray(arguments.refs) or {}

	for _, ref in refs do
		assert(type(ref) == "string" and ref ~= "", "refs must be a list of strings")
		table.insert(argv, ref)
	end

	appendOption(argv, "group", arguments.group)
	appendFlag(argv, "dry-run", arguments.dryRun)
	appendOption(argv, "workspace", arguments.workspace)
	table.insert(argv, "--json")
	return argv
end

-- Every tool the MCP server offers, in the order tools/list reports them. Tools map their
-- fields onto a CLI command, and those that need more than that supply their own build.
local tools: { Tool } = {
	{
		name = "orion_workspaces",
		description = "List Orion workspaces and the active workspace, or the archived ones.",
		annotations = { readOnlyHint = true },
		command = { "workspace", "list" },
		json = true,
		fields = {
			{
				name = "archived",
				kind = "boolean",
				description = "List archived workspaces instead.",
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
				description = "Required for show.",
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
		name = "orion_add_item",
		description = "Add a work item, or a component for a system diagram, to the canvas.",
		command = { "add" },
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
		description = "Change fields on an existing Orion item or group.",
		command = { "set" },
		json = true,
		fields = {
			{ name = "id", kind = "id", required = true, at = "positional" },
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
			{ name = "note", kind = "string", at = "option" },
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
		description = "Add a canvas note, optionally inside a group or a dependency link.",
		command = { "note" },
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
		description = "List image nodes in an Orion workspace.",
		annotations = { readOnlyHint = true },
		command = { "media", "list" },
		json = true,
		fields = { workspaceField },
	},
	{
		name = "orion_add_image",
		description = "Import a local PNG, JPEG, GIF, or WebP file as an image node. The CLI copies it into the workspace assets folder.",
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
		command = { "link" },
		fields = {
			{ name = "from", kind = "id", required = true, at = "positional" },
			{ name = "to", kind = "id", required = true, at = "positional" },
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
		command = { "unlink" },
		fields = {
			{ name = "from", kind = "id", required = true, at = "positional" },
			{ name = "to", kind = "id", required = true, at = "positional" },
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
		command = { "move" },
		fields = {
			{ name = "id", kind = "id", required = true, at = "positional" },
			workspaceField,
			{ name = "group", kind = "id", at = "option" },
		},
		build = buildMoveArgv,
	},
	{
		name = "orion_remove",
		description = "Delete an item from the canvas. Use orion_remove_group for a group.",
		annotations = { destructiveHint = true },
		command = { "remove" },
		fields = {
			{ name = "id", kind = "id", required = true, at = "positional" },
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
			{ name = "id", kind = "id", required = true, at = "positional" },
			{ name = "ref", kind = "string", required = true, minLength = 1, at = "positional" },
			workspaceField,
		},
	},
	{
		name = "orion_create_workspace",
		description = "Create an Orion workspace. Without a name, one is derived from the label.",
		command = { "workspace", "create" },
		fields = {
			{
				name = "name",
				kind = "workspace",
				description = "Workspace name. Omit it to derive one from label.",
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
		description = "Change a workspace's display label. The name and folder stay the same.",
		command = { "workspace", "rename" },
		fields = {
			{ name = "name", kind = "workspace", required = true, at = "positional" },
			{ name = "label", kind = "string", required = true, minLength = 1, at = "positional" },
		},
	},
	{
		name = "orion_archive_workspace",
		description = "Archive a workspace so it leaves the workspace list. Its data stays in place. The active workspace can't be archived.",
		command = { "workspace", "archive" },
		fields = {
			{ name = "name", kind = "workspace", required = true, at = "positional" },
		},
	},
	{
		name = "orion_restore_workspace",
		description = "Restore an archived Orion workspace with its data.",
		command = { "workspace", "restore" },
		fields = {
			{ name = "name", kind = "workspace", required = true, at = "positional" },
		},
	},
	{
		name = "orion_select_workspace",
		description = "Set the active Orion workspace shown by the app.",
		command = { "workspace", "use" },
		fields = {
			{ name = "name", kind = "workspace", required = true, at = "positional" },
		},
	},
	{
		name = "orion_ingest",
		description = "Import work from the workspace's configured sources into Unsorted, and refresh the cards they track, such as pull request states from GitHub.",
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
		command = { "import" },
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
