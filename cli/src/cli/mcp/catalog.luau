local json = require("@std/json")

type FieldKind = "string" | "id" | "workspace" | "enum" | "boolean" | "strings" | "int"
type Placement = "positional" | "option" | "flag" | "csv"

type Field = {
	name: string,
	kind: FieldKind,
	at: Placement,
	flag: string?,
	required: boolean?,
	description: string?,
	values: { string }?,
	minLength: number?,
}

type Tool = {
	name: string,
	description: string,
	command: { string },
	fields: { Field },
	json: boolean?,
	annotations: { [string]: boolean }?,
	build: ((json.Object) -> { string })?,
}

local STATUSES = { "todo", "active", "review", "blocked", "deferred", "done" }
local WORKSPACE_PATTERN = "^[a-z0-9]+(?:-[a-z0-9]+)*$"

local workspace: Field = {
	name = "workspace",
	kind = "workspace",
	description = "Workspace name. Omit to use the workspace selected in Orion.",
	at = "option",
	flag = "workspace",
}

local function absent(value: json.Value): boolean
	return value == nil or value == json.null
end

local function requiredString(args: json.Object, name: string): string
	local value = args[name]
	assert(type(value) == "string" and value ~= "", `missing {name}`)
	return value
end

local function optionalString(value: json.Value): string?
	if absent(value) then
		return nil
	end

	assert(type(value) == "string", "expected a string")
	return value
end

local function appendOption(argv: { string }, flag: string, value: json.Value)
	if absent(value) then
		return
	end

	assert(type(value) == "string" or type(value) == "number", `expected {flag} to be a string or number`)
	table.insert(argv, `--{flag}`)
	table.insert(argv, tostring(value))
end

local function appendWorkspace(argv: { string }, args: json.Object)
	appendOption(argv, "workspace", args.workspace)
end

local function appendFlag(argv: { string }, flag: string, value: json.Value)
	if value == true then
		table.insert(argv, `--{flag}`)
	end
end

local function property(field: Field): json.Object
	local schema: json.Object

	if field.kind == "boolean" then
		schema = json.object({ type = "boolean" })
	elseif field.kind == "int" then
		schema = json.object({ type = "integer", minimum = 1 })
	elseif field.kind == "strings" then
		schema = json.object({
			type = "array",
			items = json.object({ type = "string", minLength = 1 }),
			minItems = 1,
		})
	elseif field.kind == "enum" then
		local values: json.Array = {}

		for _, value in field.values or {} do
			table.insert(values, value)
		end

		schema = json.object({ type = "string", enum = values })
	elseif field.kind == "workspace" then
		schema = json.object({ type = "string", pattern = WORKSPACE_PATTERN })
	else
		schema = json.object({ type = "string" })

		if field.minLength or field.kind == "id" then
			schema.minLength = field.minLength or 1
		end
	end

	if field.description then
		schema.description = field.description
	end

	return schema
end

local function genericArgv(tool: Tool, args: json.Object): { string }
	local argv = table.clone(tool.command)

	for _, field in tool.fields do
		if field.at == "positional" then
			table.insert(argv, requiredString(args, field.name))
		end
	end

	for _, field in tool.fields do
		local value = args[field.name]

		if field.at == "option" then
			if absent(value) then
				assert(not field.required, `missing {field.name}`)
			else
				appendOption(argv, field.flag or field.name, value)
			end
		elseif field.at == "flag" then
			appendFlag(argv, field.flag or field.name, value)
		elseif field.at == "csv" then
			local list = if absent(value) then nil else json.asArray(value)
			assert(list and #list > 0, `missing {field.name}`)

			local ids: { string } = {}

			for _, id in list do
				assert(type(id) == "string" and id ~= "", `missing {field.name}`)
				table.insert(ids, id)
			end

			table.insert(argv, `--{field.flag or field.name}`)
			table.insert(argv, table.concat(ids, ","))
		end
	end

	if tool.json then
		table.insert(argv, "--json")
	end

	return argv
end

local function inspectArgv(args: json.Object): { string }
	local view = requiredString(args, "view")
	local argv = { view }

	if view == "show" then
		table.insert(argv, requiredString(args, "id"))
	elseif view == "list" then
		appendOption(argv, "group", args.group)
		appendFlag(argv, "all", args.all)
	else
		assert(
			view == "ready" or view == "groups" or view == "matches",
			"view must be list, ready, groups, matches, or show"
		)
	end

	appendWorkspace(argv, args)
	table.insert(argv, "--json")
	return argv
end

local function moveArgv(args: json.Object): { string }
	local argv = { "move", requiredString(args, "id") }
	local group = optionalString(args.group)

	if group then
		table.insert(argv, "--to")
		table.insert(argv, group)
	else
		table.insert(argv, "--top")
	end

	appendWorkspace(argv, args)
	return argv
end

local TOOLS: { Tool } = {
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
				values = { "list", "ready", "groups", "matches", "show" },
				at = "positional",
			},
			workspace,
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
		build = inspectArgv,
	},
	{
		name = "orion_add_item",
		description = "Add a work item to the canvas.",
		command = { "add" },
		json = true,
		fields = {
			{ name = "title", kind = "string", required = true, minLength = 1, at = "positional" },
			workspace,
			{ name = "group", kind = "id", at = "option" },
			{ name = "repo", kind = "string", at = "option" },
			{ name = "pr", kind = "int", at = "option" },
			{ name = "status", kind = "enum", values = STATUSES, at = "option" },
		},
	},
	{
		name = "orion_update_item",
		description = "Change fields on an existing Orion item or group.",
		command = { "set" },
		json = true,
		fields = {
			{ name = "id", kind = "id", required = true, at = "positional" },
			workspace,
			{ name = "label", kind = "string", at = "option" },
			{ name = "status", kind = "enum", values = STATUSES, at = "option" },
			{
				name = "who",
				kind = "enum",
				values = { "you", "review", "ci", "" },
				description = "Whose move: you, review, or ci. Empty clears it.",
				at = "option",
			},
			{ name = "note", kind = "string", at = "option" },
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
			workspace,
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
		fields = { workspace },
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
			workspace,
			{ name = "group", kind = "id", at = "option" },
		},
	},
	{
		name = "orion_link",
		description = "Connect two items, optionally as a related link that does not block work.",
		command = { "link" },
		fields = {
			{ name = "from", kind = "id", required = true, at = "positional" },
			{ name = "to", kind = "id", required = true, at = "positional" },
			workspace,
			{ name = "related", kind = "boolean", at = "flag", flag = "related" },
		},
	},
	{
		name = "orion_unlink",
		description = "Remove a dependency or related link between two items.",
		command = { "unlink" },
		fields = {
			{ name = "from", kind = "id", required = true, at = "positional" },
			{ name = "to", kind = "id", required = true, at = "positional" },
			workspace,
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
			workspace,
		},
	},
	{
		name = "orion_move",
		description = "Move an item into a group or to the top level.",
		command = { "move" },
		fields = {
			{ name = "id", kind = "id", required = true, at = "positional" },
			workspace,
			{ name = "group", kind = "id", at = "option" },
		},
		build = moveArgv,
	},
	{
		name = "orion_remove",
		description = "Delete an item or group from the canvas.",
		annotations = { destructiveHint = true },
		command = { "remove" },
		fields = {
			{ name = "id", kind = "id", required = true, at = "positional" },
			workspace,
		},
	},
	{
		name = "orion_create_workspace",
		description = "Create an Orion workspace.",
		command = { "workspace", "create" },
		fields = {
			{ name = "name", kind = "workspace", required = true, at = "positional" },
			{ name = "label", kind = "string", at = "option" },
			{ name = "owner", kind = "string", at = "option" },
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
			workspace,
			{ name = "dryRun", kind = "boolean", at = "flag", flag = "dry-run" },
			{ name = "discover", kind = "boolean", at = "flag", flag = "discover" },
		},
	},
}

local BY_NAME: { [string]: Tool } = {}

for _, tool in TOOLS do
	BY_NAME[tool.name] = tool
end

local function schema(): json.Object
	local tools: json.Array = {}

	for _, tool in TOOLS do
		local properties: { [string]: json.Value } = {}
		local required: json.Array = {}

		for _, field in tool.fields do
			properties[field.name] = property(field)

			if field.required then
				table.insert(required, field.name)
			end
		end

		local inputSchema = json.object({
			type = "object",
			properties = json.object(properties),
			additionalProperties = false,
		})

		if #required > 0 then
			inputSchema.required = required
		end

		local entry = json.object({
			name = tool.name,
			description = tool.description,
			inputSchema = inputSchema,
		})

		if tool.annotations then
			local annotations: { [string]: json.Value } = {}

			for key, value in tool.annotations do
				annotations[key] = value
			end

			entry.annotations = json.object(annotations)
		end

		table.insert(tools, entry)
	end

	return json.object({ tools = tools })
end

local function argv(name: string, args: json.Object): { string }
	local tool = assert(BY_NAME[name], `unknown tool: {name}`)

	if tool.build then
		return tool.build(args)
	end

	return genericArgv(tool, args)
end

return table.freeze({
	argv = argv,
	schema = schema,
})
