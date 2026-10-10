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

local WHO = table.clone(fieldValues.who)
table.insert(WHO, "")

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

-- Every tool the MCP server offers, in the order tools/list reports them. Tools map their
-- fields onto a CLI command, and those that need more than that supply their own build.
local tools: { Tool } = {
	{
		name = "orion_workspaces",
		description = "List Orion workspaces and the active workspace.",
		annotations = { readOnlyHint = true },
		command = { "workspace", "list" },
		json = true,
		fields = {},
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
			{ name = "repo", kind = "string", at = "option" },
			{ name = "pr", kind = "int", at = "option" },
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
			{ name = "repo", kind = "string", at = "option" },
			{ name = "pr", kind = "int", at = "option" },
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
		command = { "group" },
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
		description = "Delete an item or group from the canvas.",
		annotations = { destructiveHint = true },
		command = { "remove" },
		fields = {
			{ name = "id", kind = "id", required = true, at = "positional" },
			workspaceField,
		},
	},
	{
		name = "orion_create_workspace",
		description = "Create an Orion workspace.",
		command = { "workspace", "create" },
		fields = {
			{ name = "name", kind = "workspace", required = true, at = "positional" },
			{ name = "label", kind = "string", at = "option" },
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
		name = "orion_sync",
		description = "Refresh pull request cards from GitHub. Discovery adds open authored PRs to Inbox when requested.",
		annotations = { openWorldHint = true },
		command = { "sync" },
		json = true,
		fields = {
			workspaceField,
			{ name = "dryRun", kind = "boolean", at = "flag", flag = "dry-run" },
			{ name = "discover", kind = "boolean", at = "flag", flag = "discover" },
		},
	},
}

return table.freeze(tools)
