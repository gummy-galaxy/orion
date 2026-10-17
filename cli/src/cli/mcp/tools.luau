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

local INSPECT_COMMANDS: { { string } } = {}

for _, command in VIEW_COMMANDS do
	table.insert(INSPECT_COMMANDS, command)
end

local REF_DESCRIPTION =
	"Outside work to attach: a GitHub or Jira URL, source:key such as jira:ABC-1, or branch:owner/name@branch."
local DEPRECATED_REPO = "Deprecated: with pr, use ref with the pull request URL instead."
local DEPRECATED_PR = "Deprecated: use ref with the pull request URL instead."
local DRY_RUN = "Preview the changes and the current revision without writing."
local IF_REVISION =
	"Write only if the canvas is still at this revision, as a dry run printed it. Otherwise nothing is written."
local WHERE = 'Select targets with an expression instead of ids, such as label ~ "text".'
local NOTE_STYLE =
	"Write it as a plain-language summary: Markdown for structure, code formatting for code, file paths, and identifiers, and no pull request or issue links in the text. Attach those as refs on a card."
local NOTE_DESCRIPTION = "Replaces the whole note. " .. NOTE_STYLE

local WHO = table.clone(fieldValues.who)
table.insert(WHO, "")

local CLEARABLE_COLORS = table.clone(fieldValues.colors)
table.insert(CLEARABLE_COLORS, "")

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

-- Batch commands take ids or a where expression, and share the preview and revision guard.
local function batchFields(idsDescription: string): { Field }
	return {
		{ name = "ids", kind = "strings", description = idsDescription, at = "variadic" },
		workspaceField,
		{ name = "where", kind = "string", minLength = 1, description = WHERE, at = "option" },
		{ name = "dryRun", kind = "boolean", description = DRY_RUN, at = "flag", flag = "dry-run" },
		{ name = "ifRevision", kind = "int", description = IF_REVISION, at = "option", flag = "if-revision" },
	}
end

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

-- Group ids are one list argument, which the CLI takes as trailing positionals.
local function buildTidyArgv(arguments: json.Object): { string }
	local argv = { "group", "tidy" }
	local ids = json.asArray(arguments.ids) or {}

	for _, id in ids do
		assert(type(id) == "string" and id ~= "", "ids must be a list of strings")
		table.insert(argv, id)
	end

	appendOption(argv, "where", arguments.where)
	appendFlag(argv, "dry-run", arguments.dryRun)
	appendOption(argv, "if-revision", arguments.ifRevision)
	appendOption(argv, "canvas", arguments.workspace)
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
		commands = INSPECT_COMMANDS,
		json = true,
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
		command = { "card", "add" },
		json = true,
		fields = {
			{
				name = "title",
				kind = "string",
				required = true,
				minLength = 1,
				description = "What the work is.",
				at = "positional",
				flag = "label",
			},
			workspaceField,
			{ name = "group", kind = "id", description = "Group to add it to.", at = "option" },
			{ name = "status", kind = "enum", values = fieldValues.statuses, at = "option" },
			{
				name = "who",
				kind = "enum",
				values = fieldValues.who,
				description = "Whose move: you, review, or ci.",
				at = "option",
			},
			{ name = "note", kind = "string", description = "Free-form note.", at = "option" },
			kindField,
			shapeField,
			colorField,
			{ name = "repo", kind = "string", description = DEPRECATED_REPO, at = "option" },
			{ name = "pr", kind = "int", description = DEPRECATED_PR, at = "option" },
			{ name = "ref", kind = "string", description = REF_DESCRIPTION, at = "option" },
		},
	},
	{
		name = "orion_update_item",
		description = "Change fields on an existing Orion card.",
		command = { "card", "set" },
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
			{ name = "note", kind = "string", description = NOTE_DESCRIPTION .. " Empty clears it.", at = "option" },
			kindField,
			shapeField,
			colorField,
			{ name = "repo", kind = "string", description = DEPRECATED_REPO, at = "option" },
			{ name = "pr", kind = "int", description = DEPRECATED_PR, at = "option" },
			{ name = "ref", kind = "string", description = REF_DESCRIPTION, at = "option" },
		},
	},
	{
		name = "orion_done",
		description = "Mark items done, by id or by a where expression. A dry run shows what would change.",
		command = { "card", "done" },
		json = true,
		fields = batchFields("Item ids to mark done."),
	},
	{
		name = "orion_add_note",
		description = "Add a canvas note, optionally inside a group or a dependency link. " .. NOTE_STYLE,
		command = { "note", "add" },
		json = true,
		fields = {
			{ name = "text", kind = "string", required = true, minLength = 1, at = "positional" },
			workspaceField,
			{ name = "group", kind = "id", description = "Group to add it to.", at = "option" },
			{ name = "after", kind = "id", description = "Item the note follows.", at = "option" },
			{ name = "before", kind = "id", description = "Item the note leads into.", at = "option" },
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
				flag = "file",
			},
			{ name = "label", kind = "string", minLength = 1, description = "Label for the image.", at = "option" },
			workspaceField,
			{ name = "group", kind = "id", description = "Group to add it to.", at = "option" },
		},
	},
	{
		name = "orion_themes",
		description = "List the theme files in the Orion data folder, and whether each one can be used.",
		annotations = { readOnlyHint = true },
		command = { "theme", "list" },
		json = true,
		fields = {},
	},
	{
		name = "orion_add_theme",
		description = "Check a theme JSON file against the token contract and copy it into the Orion data folder, where the app lists it. Unknown tokens are reported and ignored. A file that is malformed or sets a bad value is refused.",
		command = { "theme", "add" },
		json = true,
		fields = {
			{
				name = "path",
				kind = "string",
				required = true,
				minLength = 1,
				description = "Absolute path to a local .json theme file.",
				at = "positional",
				flag = "file",
			},
		},
	},
	{
		name = "orion_remove_theme",
		description = "Delete a theme file from the Orion data folder by the file name orion_themes lists.",
		annotations = { destructiveHint = true },
		command = { "theme", "remove" },
		json = true,
		fields = {
			{
				name = "file",
				kind = "string",
				required = true,
				minLength = 1,
				description = "Theme file name, such as dusk.json.",
				at = "positional",
			},
		},
	},
	{
		name = "orion_link",
		description = "Link items so each waits on the one before it. Give more than two items to link a chain. Use related for a link that does not block work. Linking an already linked pair updates that link.",
		command = { "link", "add" },
		json = true,
		fields = {
			{
				name = "from",
				kind = "id",
				required = true,
				description = "The item that has to happen first.",
				at = "positional",
			},
			{
				name = "to",
				kind = "id",
				required = true,
				description = "The item that waits on it.",
				at = "positional",
			},
			{
				name = "next",
				kind = "strings",
				description = "Further items in the chain, each waiting on the one before it.",
				at = "variadic",
			},
			workspaceField,
			{
				name = "related",
				kind = "boolean",
				description = "Link without blocking.",
				at = "flag",
			},
			{ name = "dryRun", kind = "boolean", description = DRY_RUN, at = "flag", flag = "dry-run" },
			{ name = "ifRevision", kind = "int", description = IF_REVISION, at = "option", flag = "if-revision" },
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
			{ name = "from", kind = "id", required = true, description = "Link source.", at = "positional" },
			{ name = "to", kind = "id", required = true, description = "Link target.", at = "positional" },
			workspaceField,
		},
	},
	{
		name = "orion_insert",
		description = "Put an item into an existing link: the link from between to its target is replaced by one through the item.",
		command = { "link", "insert" },
		json = true,
		fields = {
			{
				name = "id",
				kind = "id",
				required = true,
				description = "Item to place in the link.",
				at = "positional",
			},
			{
				name = "between",
				kind = "id",
				required = true,
				description = "Source item whose link is replaced.",
				at = "option",
			},
			{
				name = "targets",
				kind = "strings",
				description = "Target items whose links are replaced.",
				at = "variadic",
				flag = "target",
			},
			workspaceField,
			{ name = "dryRun", kind = "boolean", description = DRY_RUN, at = "flag", flag = "dry-run" },
			{ name = "ifRevision", kind = "int", description = IF_REVISION, at = "option", flag = "if-revision" },
		},
	},
	{
		name = "orion_query",
		description = "Find cards and groups with an expression. Fields: kind, repo, status, recordedStatus, group, draft, label, pr, ref. Compare quoted values with = or !=; label and ref also take ~ for case-insensitive text.",
		annotations = { readOnlyHint = true },
		command = { "node", "query" },
		json = true,
		fields = {
			{
				name = "where",
				kind = "string",
				required = true,
				minLength = 1,
				description = 'Expression selecting cards or groups, such as status = "blocked".',
				at = "option",
			},
			workspaceField,
			{ name = "all", kind = "boolean", description = "Include done items.", at = "flag" },
		},
	},
	{
		name = "orion_move",
		description = "Move items or groups into a group, or to the top level. Give group or top.",
		command = { "node", "move" },
		json = true,
		fields = {
			{ name = "ids", kind = "strings", description = "Item or group ids to move.", at = "variadic" },
			workspaceField,
			{ name = "where", kind = "string", minLength = 1, description = WHERE, at = "option" },
			{ name = "group", kind = "id", description = "Destination group.", at = "option", flag = "to" },
			{ name = "top", kind = "boolean", description = "Move to the top level.", at = "flag" },
			{ name = "dryRun", kind = "boolean", description = DRY_RUN, at = "flag", flag = "dry-run" },
			{ name = "ifRevision", kind = "int", description = IF_REVISION, at = "option", flag = "if-revision" },
		},
	},
	{
		name = "orion_remove",
		description = "Delete items from the canvas, by id or a where expression. Use orion_remove_group for a group.",
		annotations = { destructiveHint = true },
		command = { "node", "remove" },
		json = true,
		fields = {
			{ name = "ids", kind = "strings", description = "Item ids to delete.", at = "variadic" },
			workspaceField,
			{ name = "where", kind = "string", minLength = 1, description = WHERE, at = "option" },
			{ name = "dryRun", kind = "boolean", description = DRY_RUN, at = "flag", flag = "dry-run" },
			{ name = "ifRevision", kind = "int", description = IF_REVISION, at = "option", flag = "if-revision" },
			{
				name = "reconnect",
				kind = "boolean",
				description = "Reconnect the links through each removed item that has at most one incoming and one outgoing link.",
				at = "flag",
			},
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
		name = "orion_update_group",
		description = "Change a group's label, blurb, arrangement, cover, or background. Empty cover or background clears it.",
		command = { "group", "set" },
		json = true,
		fields = {
			{ name = "id", kind = "id", required = true, description = "Group id.", at = "positional" },
			workspaceField,
			{ name = "label", kind = "string", minLength = 1, description = "New label.", at = "option" },
			{ name = "blurb", kind = "string", description = "Group description.", at = "option" },
			{
				name = "arrange",
				kind = "enum",
				values = fieldValues.arrangements,
				description = "How the app lays out the group: auto flows by dependency, custom keeps positions.",
				at = "option",
			},
			{
				name = "cover",
				kind = "string",
				description = "Image asset id for the cover, from orion_add_image. Empty clears it.",
				at = "option",
			},
			{
				name = "background",
				kind = "string",
				description = "Color, color token such as card.background, or image asset id. Empty clears it.",
				at = "option",
			},
			{
				name = "header",
				kind = "string",
				description = "Markdown with layout HTML shown under the group's title. Empty clears it.",
				at = "option",
			},
			{
				name = "color",
				kind = "enum",
				values = CLEARABLE_COLORS,
				description = "The group's tint. Components inside take it unless they set their own. Empty clears it.",
				at = "option",
			},
		},
	},
	{
		name = "orion_remove_group",
		description = "Delete groups and everything inside them, by id or a where expression. A dry run lists what would go.",
		annotations = { destructiveHint = true },
		command = { "group", "remove" },
		json = true,
		fields = batchFields("Group ids to delete, with everything inside them."),
	},
	{
		name = "orion_ungroup",
		description = "Dissolve groups, keeping their items in place.",
		command = { "group", "ungroup" },
		json = true,
		fields = batchFields("Group ids to dissolve."),
	},
	{
		name = "orion_tidy",
		description = "Mark groups for the app to lay out in place, deepest first, such as after adding cards in bulk. The app does the layout, so appConnected in the result says whether it runs now or when the app next opens. Custom groups keep their arrangement.",
		command = { "group", "tidy" },
		json = true,
		fields = {
			{
				name = "ids",
				kind = "strings",
				description = "Groups to tidy. Give ids or where, not both.",
				at = "positional",
			},
			{
				name = "where",
				kind = "string",
				minLength = 1,
				description = 'Select groups with a query expression instead of ids, such as label ~ "release".',
				at = "option",
			},
			workspaceField,
			{
				name = "dryRun",
				kind = "boolean",
				description = "List the groups and the current revision without marking them.",
				at = "flag",
				flag = "dry-run",
			},
			{
				name = "ifRevision",
				kind = "int",
				minimum = 0,
				description = "Mark only if the canvas is still at this revision, such as the one a dry run reported.",
				at = "option",
				flag = "if-revision",
			},
		},
		build = buildTidyArgv,
	},
	{
		name = "orion_remove_ref",
		description = "Take a GitHub, Jira, or branch ref off an item. Name it by the key orion_inspect lists, or by its URL.",
		command = { "ref", "remove" },
		json = true,
		fields = {
			{ name = "id", kind = "id", required = true, description = "Item id.", at = "positional" },
			{
				name = "ref",
				kind = "string",
				required = true,
				minLength = 1,
				description = "The ref's key as orion_inspect lists it, such as owner/name#12, or a URL or source:key.",
				at = "positional",
			},
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
		name = "orion_update_canvas",
		description = "Set a canvas's cover or background. Empty clears it.",
		command = { "canvas", "set" },
		fields = {
			workspaceField,
			{
				name = "cover",
				kind = "string",
				description = "Image asset id for the cover, from orion_add_image. Empty clears it.",
				at = "option",
			},
			{
				name = "background",
				kind = "string",
				description = "Color, color token such as card.background, or image asset id. Empty clears it.",
				at = "option",
			},
			{
				name = "header",
				kind = "string",
				description = "Markdown with layout HTML shown over the top of the canvas. Empty clears it.",
				at = "option",
			},
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
		name = "orion_check",
		description = "Report layout problems from stored positions and sizes: overlapping siblings, children outside their group, links to missing items, and groups waiting for layout. Returns a list of {kind, ids, bounds} in canvas coordinates, with bounds null for a dangling link, and an empty list when the layout is clean.",
		annotations = { readOnlyHint = true },
		command = { "canvas", "check" },
		json = true,
		fields = {
			workspaceField,
			{
				name = "group",
				kind = "id",
				description = "Only report problems in this group and what is inside it.",
				at = "option",
			},
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
			{ name = "dryRun", kind = "boolean", description = DRY_RUN, at = "flag", flag = "dry-run" },
			{ name = "source", kind = "string", description = "Only ingest this source id.", at = "option" },
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
			{ name = "dryRun", kind = "boolean", description = DRY_RUN, at = "flag", flag = "dry-run" },
			{
				name = "discover",
				kind = "boolean",
				description = "Add your open pull requests that aren't on the canvas to an Inbox group.",
				at = "flag",
			},
		},
	},
	{
		name = "orion_sources",
		description = "List the canvas's ingestion sources: GitHub, Jira, and hop.",
		annotations = { readOnlyHint = true },
		command = { "source", "list" },
		json = true,
		fields = { workspaceField },
	},
	{
		name = "orion_import",
		description = "Add a card for each GitHub or Jira URL, or source:key, in one step. Refs already on the canvas are skipped. Refs that don't resolve are reported and skipped, and the call fails if any did.",
		annotations = { openWorldHint = true },
		command = { "card", "import" },
		json = true,
		fields = {
			{
				name = "refs",
				kind = "strings",
				required = true,
				description = "GitHub or Jira URLs, or source:key such as jira:ABC-1.",
				at = "variadic",
			},
			workspaceField,
			{ name = "group", kind = "id", description = "Group to add the cards to.", at = "option" },
			{
				name = "dryRun",
				kind = "boolean",
				description = "Preview the cards without writing.",
				at = "flag",
				flag = "dry-run",
			},
			{ name = "ifRevision", kind = "int", description = IF_REVISION, at = "option", flag = "if-revision" },
		},
	},
	{
		name = "orion_suggest",
		description = "Suggest groups for ungrouped cards, using the given agent or the configured one. A dry run shows the suggestions without saving them.",
		annotations = { openWorldHint = true },
		command = { "suggestion", "find" },
		json = true,
		fields = {
			workspaceField,
			{
				name = "agent",
				kind = "enum",
				values = { "claude", "codex", "none" },
				description = "Agent that writes the suggestions: claude, codex, or none.",
				at = "option",
			},
			{
				name = "scope",
				kind = "enum",
				values = { "unsorted", "all" },
				description = "Cards to suggest groups for: unsorted, or all.",
				at = "option",
			},
			{
				name = "dryRun",
				kind = "boolean",
				description = "Show suggestions without writing.",
				at = "flag",
				flag = "dry-run",
			},
		},
	},
	{
		name = "orion_suggestions",
		description = "List pending group suggestions.",
		annotations = { readOnlyHint = true },
		command = { "suggestion", "list" },
		json = true,
		fields = { workspaceField },
	},
	{
		name = "orion_apply_suggestions",
		description = "Apply group suggestions by id, or all of them.",
		command = { "suggestion", "apply" },
		fields = {
			{ name = "ids", kind = "strings", description = "Suggestion ids.", at = "variadic" },
			workspaceField,
			{ name = "all", kind = "boolean", description = "Apply every suggestion.", at = "flag" },
		},
	},
	{
		name = "orion_dismiss_suggestions",
		description = "Dismiss group suggestions by id, or all of them.",
		command = { "suggestion", "dismiss" },
		fields = {
			{ name = "ids", kind = "strings", description = "Suggestion ids.", at = "variadic" },
			workspaceField,
			{ name = "all", kind = "boolean", description = "Dismiss every suggestion.", at = "flag" },
		},
	},
	{
		name = "orion_backups",
		description = "List saved revisions of a canvas.",
		annotations = { readOnlyHint = true },
		command = { "backup", "list" },
		json = true,
		fields = { workspaceField },
	},
	{
		name = "orion_restore_backup",
		description = "Restore a saved revision as a new revision. The current canvas is backed up first.",
		command = { "backup", "restore" },
		fields = {
			{
				name = "revision",
				kind = "string",
				required = true,
				minLength = 1,
				description = "Revision to restore, from orion_backups.",
				at = "positional",
			},
			workspaceField,
		},
	},
	{
		name = "orion_focus",
		description = "Show the group open in the Orion app and what is selected, so you can answer questions about what the person is looking at.",
		annotations = { readOnlyHint = true },
		command = { "focus" },
		json = true,
		fields = { workspaceField },
	},
	{
		name = "orion_server_status",
		description = "Report whether the Orion app's server is running, and where it listens.",
		annotations = { readOnlyHint = true },
		command = { "server", "status" },
		json = true,
		fields = {},
	},
}

return table.freeze(tools)
