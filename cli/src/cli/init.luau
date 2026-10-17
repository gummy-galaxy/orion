local cli = require("@batteries/cli")
local json = require("@std/json")
local process = require("@std/process")

local backup = require("@root/cli/backup")
local batchEdit = require("@root/cli/batchEdit")
local canvas = require("@root/cli/canvas")
local checkStyleAssets = require("@root/style/checkStyleAssets")
local context = require("@root/cli/context")
local defaultRun = require("@root/command")
local describeCommands = require("@root/cli/describeCommands")
local focus = require("@root/cli/focus")
local formatRefreshReport = require("@root/github/formatRefreshReport")
local getAdapter = require("@root/adapters/getAdapter")
local getRefs = require("@root/refs/getRefs")
local getVersion = require("@root/getVersion")
local githubTypes = require("@root/github/types")
local graph = require("@root/graph")
local importCommand = require("@root/cli/import")
local ingest = require("@root/cli/ingest")
local mcp = require("@root/cli/mcp")
local media = require("@root/cli/media")
local orientation = require("@root/cli/orientation")
local pad = require("@root/render/pad")
local parseCommaList = require("@root/cli/parseCommaList")
local render = require("@root/render")
local renderGroup = require("@root/render/group")
local requestedRevision = require("@root/cli/requestedRevision")
local resolveNodeId = require("@root/resolveNodeId")
local resolveRef = require("@root/adapters/resolveRef")
local runEdit = require("@root/cli/runEdit")
local selectItems = require("@root/query/selectItems")
local server = require("@root/cli/server")
local source = require("@root/cli/source")
local store = require("@root/store")
local suggestion = require("@root/cli/suggestion")
local tidy = require("@root/cli/tidy")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item
type RefreshReport = githubTypes.Report
type Context = context.Context

type Command = context.Command

export type Dependencies = context.Dependencies

type Resolved = {
	runner: types.CommandRunner,
	write: (string) -> (),
	dataDir: string,
	workspace: string?,
	now: () -> string,
}

local SUMMARY = "orion — keep a graph of work up to date from the command line"
local SYNC_DEPRECATION = "`orion sync` is deprecated and will be removed. `orion ingest` refreshes pull requests too."

-- Commands with their own modules, each defining its subcommands and running them.
local COMMANDS: { [string]: Command } = {
	backup = backup,
	canvas = canvas,
	focus = focus,
	ingest = ingest,
	mcp = mcp,
	media = media,
	server = server,
	source = source,
	suggestion = suggestion,
}

local ABOUT = [[
Statuses: todo, active, review, blocked, deferred, done.
  Listed statuses are derived: todo shows as ready once nothing it waits on is open,
  and as blocked while something is. Notes pass blocking through and never count as work.
Repositories are "owner/name".
Data lives in Orion's user data folder (run orion canvas path to see it); set ORION_DATA_DIR to change it.
Set ORION_CANVAS to pick a canvas, as --canvas does for a single command.
The Orion app talks to orion server start, which watches the data files.
Use orion server status [--json] to find the running server.
While the app is open, orion focus shows its open group and selection.]]

local QUERY_HELP = [[
Fields: kind, repo, status, recordedStatus, group, draft, label, pr, ref.
Compare quoted values with = or !=; label and ref also support ~ for case-insensitive text.
Combine with and, or, not, and parentheses. Missing fields never match.]]

local function addHelpFlag(parser: cli.Parser)
	parser:add("help", "flag", { help = "Show this help", aliases = { "h" } })
end

local function addJsonFlag(parser: cli.Parser)
	parser:add("json", "flag", { help = "Print JSON" })
end

local function addCanvasOption(parser: cli.Parser)
	parser:add("canvas", "option", { help = "Use this canvas for this command" })
end

local function addRefOption(parser: cli.Parser)
	parser:add("ref", "option", {
		help = "Attach outside work: a GitHub or Jira URL, source:key such as jira:ABC-1, or branch:owner/name@branch",
	})
end

-- Item fields, which cards take. Groups take their own, set with group set.
local function addFieldOptions(parser: cli.Parser)
	parser:add("status", "option", { help = "todo, active, review, blocked, deferred, or done" })
	parser:add(
		"repo",
		"option",
		{ help = "Repository, as owner/name. Deprecated: with --pr, use --ref with the pull request URL" }
	)
	parser:add("pr", "option", { help = "Pull request number. Deprecated: use --ref with the pull request URL" })
	parser:add("who", "option", { help = "Whose move: you, review, or ci (empty to clear)" })
	parser:add("note", "option", { help = "Free-form note (empty to clear)" })
	parser:add("kind", "option", { help = "step, or gate for one that's done once everything it waits on is" })
end

type Parsers = {
	root: cli.Parser,
	commands: { [string]: cli.Parser },
}

local function createParsers(): Parsers
	local root = cli.parser()
	addHelpFlag(root)
	root:add("version", "flag", { help = "Print the Orion version and build commit" })
	addCanvasOption(root)
	local commands: { [string]: cli.Parser } = {}

	-- Adds a command under a parent, with the help flag and --canvas option every command takes.
	local function addCommand(parent: cli.Parser, name: string, help: string): cli.Parser
		local parser = parent:subcommand(name, { help = help })
		addHelpFlag(parser)
		addCanvasOption(parser)
		return parser
	end

	local function addBatchOptions(parser: cli.Parser, help: string)
		parser:add("ids", "variadic", { help = help })
		parser:add("where", "option", { help = "Select targets with an expression instead of ids" })
		parser:add("dry-run", "flag", { help = "Preview changes and current revision without writing" })
		parser:add("if-revision", "option", { help = "Write only if the document has this revision" })
		addJsonFlag(parser)
	end

	local card = addCommand(root, "card", "Work items on the canvas")

	local cardList = addCommand(card, "list", "List work items with their derived status")
	cardList:add("group", "option", { help = "Only items inside this group, by id or label" })
	cardList:add("all", "flag", { help = "Include done items" })
	addJsonFlag(cardList)

	local cardAdd = addCommand(card, "add", "Add a work item")
	cardAdd:add("label", "variadic", { help = "What the work is" })
	cardAdd:add("group", "option", { help = "Group to add it to, by id or label" })
	addFieldOptions(cardAdd)
	addRefOption(cardAdd)
	addJsonFlag(cardAdd)

	local cardSet = addCommand(card, "set", "Change an item's fields")
	cardSet:add("id", "positional", { help = "Item id" })
	cardSet:add("label", "option", { help = "New label" })
	addFieldOptions(cardSet)
	addRefOption(cardSet)
	addJsonFlag(cardSet)

	addBatchOptions(addCommand(card, "done", "Mark one or more items done"), "Item ids")
	importCommand.define(addCommand(card, "import", importCommand.help))

	local note = addCommand(root, "note", "Notes for context, decisions, and reminders")
	local noteAdd = addCommand(note, "add", "Add a note, optionally between two linked items")
	noteAdd:add("text", "variadic", { help = "Note text" })
	noteAdd:add("group", "option", { help = "Group to add it to, by id or label" })
	noteAdd:add("after", "option", { help = "Item the note follows" })
	noteAdd:add("before", "option", { help = "Item the note leads into" })
	addJsonFlag(noteAdd)

	local link = addCommand(root, "link", "Dependencies between items")

	local linkAdd = addCommand(link, "add", "Link each adjacent pair of items")
	linkAdd:add("from", "positional", { help = "The item that has to happen first" })
	linkAdd:add("to", "positional", { help = "The item that waits on it" })
	linkAdd:add("next", "variadic", { help = "Further items in the chain" })
	linkAdd:add("related", "flag", { help = "Link without blocking" })
	linkAdd:add("dry-run", "flag", { help = "Preview changes and current revision without writing" })
	linkAdd:add("if-revision", "option", { help = "Write only if the document has this revision" })
	addJsonFlag(linkAdd)

	local linkRemove = addCommand(link, "remove", "Remove the link between two items")
	linkRemove:add("from", "positional", { help = "Link source" })
	linkRemove:add("to", "positional", { help = "Link target" })

	local linkInsert = addCommand(link, "insert", "Insert an item into an existing link")
	linkInsert:add("id", "positional", { help = "Item to place in the link" })
	linkInsert:add("between", "option", { help = "Source item whose link is replaced", required = true })
	linkInsert:add("target", "variadic", { help = "Target item whose link is replaced" })
	linkInsert:add("dry-run", "flag", { help = "Preview changes and current revision without writing" })
	linkInsert:add("if-revision", "option", { help = "Write only if the document has this revision" })
	addJsonFlag(linkInsert)

	local node = addCommand(root, "node", "Any item or group")

	local nodeShow = addCommand(node, "show", "Show one item or group")
	nodeShow:add("id", "positional", { help = "Item or group id" })
	addJsonFlag(nodeShow)

	local nodeQuery = addCommand(node, "query", "Find cards and groups with an expression")
	nodeQuery:add("where", "option", { help = "Expression selecting cards or groups", required = true })
	nodeQuery:add("all", "flag", { help = "Include done items" })
	addJsonFlag(nodeQuery)

	local nodeRemove = addCommand(node, "remove", "Remove items; optionally reconnect a card's links")
	addBatchOptions(nodeRemove, "Item ids")
	nodeRemove:add("reconnect", "flag", { help = "Reconnect at most one incoming and outgoing link per item" })

	local nodeMove = addCommand(node, "move", "Move items or groups into another group")
	addBatchOptions(nodeMove, "Item or group ids")
	nodeMove:add("to", "option", { help = "Destination group, by id or label" })
	nodeMove:add("top", "flag", { help = "Move to the top level" })

	local group = addCommand(root, "group", "Groups of items")

	local groupList = addCommand(group, "list", "List groups with their progress")
	addJsonFlag(groupList)

	local groupCreate = addCommand(group, "create", "Make an empty group, optionally inside another")
	groupCreate:add("label", "variadic", { help = "Group name" })
	groupCreate:add("in", "option", { help = "Group to make it inside, by id or label" })
	addJsonFlag(groupCreate)

	local groupAdd = addCommand(group, "add", "Wrap items that share a parent in a new group")
	groupAdd:add("label", "variadic", { help = "Group name" })
	groupAdd:add("items", "option", { help = "Comma-separated ids to put in it", required = true })
	addJsonFlag(groupAdd)

	addBatchOptions(addCommand(group, "remove", "Remove groups with everything inside them"), "Group ids")

	local groupSet = addCommand(group, "set", "Change a group's fields")
	groupSet:add("id", "positional", { help = "Group id" })
	groupSet:add("label", "option", { help = "New label" })
	groupSet:add("blurb", "option", { help = "Group description" })
	groupSet:add("arrange", "option", { help = "How reflow arranges a group: auto or custom" })
	groupSet:add(
		"cover",
		"option",
		{ help = "Image asset id for the cover, from orion media insert --json (empty to clear)" }
	)
	groupSet:add(
		"background",
		"option",
		{ help = "Color, color token such as card.background, or image asset id (empty to clear)" }
	)
	groupSet:add(
		"header",
		"option",
		{ help = "Markdown with layout HTML shown under the group's title (empty to clear)" }
	)
	addJsonFlag(groupSet)

	addBatchOptions(addCommand(group, "ungroup", "Dissolve groups, keeping their items in place"), "Group ids")
	tidy.define(addCommand(group, "tidy", tidy.help))

	local ref = addCommand(root, "ref", "Outside work attached to cards")
	local refRemove = addCommand(ref, "remove", "Take a ref off an item")
	refRemove:add("id", "positional", { help = "Item id" })
	refRemove:add(
		"ref",
		"positional",
		{ help = "The ref's key as orion node show lists it, such as owner/name#12, or a URL or source:key" }
	)
	addJsonFlag(refRemove)

	local nextCommand = addCommand(root, "next", "List items that can start now, most unblocking first")
	addJsonFlag(nextCommand)

	local sync = addCommand(root, "sync", "Update pull request items from GitHub (deprecated: use ingest)")
	sync:add("discover", "flag", { help = "Add your open pull requests that aren't on the canvas to an Inbox group" })
	sync:add("dry-run", "flag", { help = "Show what would change without writing" })
	addJsonFlag(sync)

	-- Commands with their own modules define their subcommands themselves.
	for _, name in { "canvas", "server", "source", "ingest", "media", "suggestion", "backup", "mcp", "focus" } do
		local module = COMMANDS[name]
		local parser = addCommand(root, name, module.help)
		commands[name] = parser
		module.define(parser)
	end

	local helpCommand = addCommand(root, "help", "Show help for Orion or one of its commands")
	helpCommand:add("command", "variadic", { help = "Command to describe, such as card list" })

	return { root = root, commands = commands }
end

local function rootHelp(parser: cli.Parser): string
	return table.concat({
		SUMMARY,
		"",
		table.concat(orientation.help, "\n\n"),
		"",
		parser:usage("orion"),
		"",
		parser:help(),
		"",
		ABOUT,
	}, "\n")
end

-- Finds the parser for a command path such as {"card", "list"}, along with the help its parent lists for it.
local function findCommand(root: cli.Parser, names: { string }): (cli.Parser?, string?)
	local current = root
	local help: string? = nil

	for _, name in names do
		local parser: cli.Parser? = nil

		for _, command in current.commands do
			if command.name == name then
				parser = command.parser
				help = command.options.help
			end
		end

		if parser == nil then
			return nil, nil
		end

		current = parser
	end

	return current, help
end

local function commandHelp(name: string, help: string?, parser: cli.Parser): string
	local syntax = if name == "node query" then `\n\n{QUERY_HELP}` else ""
	return `{help or ""}\n\n{parser:usage(`orion {name}`)}\n\n{parser:help()}{syntax}`
end

-- Returns the help for the outermost command on the path that was given --help, if any.
local function helpFor(root: cli.Parser, names: { string }): string?
	for depth = 1, #names do
		local path = table.move(names, 1, depth, 1, {})
		local parser, help = findCommand(root, path)

		if parser and parser:has("help") then
			return commandHelp(table.concat(path, " "), help, parser)
		end
	end

	return nil
end

-- Walks the chosen commands from the root down, returning their names and the deepest parser.
local function selectedPath(root: cli.Parser): ({ string }, cli.Parser)
	local names: { string } = {}
	local current = root

	while true do
		local name, child = current:selected()

		if not (name and child) then
			return names, current
		end

		table.insert(names, name)
		current = child
	end
end

local function dependencies(options: Dependencies?): Resolved
	local given: Dependencies = options or {}
	return {
		runner = given.runner or defaultRun,
		write = given.write or print,
		dataDir = given.dataDir or store.defaultDir(),
		workspace = if given.workspace == nil then process.env.ORION_CANVAS else given.workspace,
		now = given.now or function()
			return os.date("!%Y-%m-%dT%H:%M:%SZ") :: string
		end,
	}
end

local function fields(parser: cli.Parser): graph.ItemFields
	local pr = parser:get("pr")
	local number = if pr then tonumber((pr:gsub("^#", ""))) else nil
	assert(pr == nil or number, "pr must be a number")
	return {
		label = parser:get("label"),
		blurb = parser:get("blurb"),
		status = parser:get("status"),
		repo = parser:get("repo"),
		pr = number,
		who = parser:get("who"),
		note = parser:get("note"),
		arrange = parser:get("arrange"),
		cover = parser:get("cover"),
		background = parser:get("background"),
		header = parser:get("header"),
		kind = parser:get("kind"),
	}
end

local function joined(values: { string }, what: string): string
	local text = table.concat(values, " ")
	assert(text ~= "", `missing {what}`)
	return text
end

local function required(parser: cli.Parser, name: string): string
	return assert(parser:get(name), `missing <{name}>`)
end

-- Card commands take items and group commands take groups. Each names the other when it gets the wrong one.
local function requireItem(doc: Doc, id: string)
	assert(not graph.isGroup(graph.get(doc, id)), `"{id}" is a group; use orion group set`)
end

local function requireGroup(doc: Doc, id: string)
	assert(graph.isGroup(graph.get(doc, id)), `"{id}" is an item; use orion card set`)
end

-- Attaches the --ref given to add or set, resolving it against the document's sources.
local function attachRef(doc: Doc, id: string, input: string?)
	if input then
		graph.attachRef(doc, id, resolveRef(input, doc.settings.sources))
	end
end

-- Takes a ref off an item by the key orion node show lists. A URL or source:key that isn't a key on the item resolves
-- the way --ref does, and then has to match that ref's kind too.
local function detachRef(doc: Doc, id: string, input: string): Item
	local item = graph.get(doc, id)
	assert(not graph.isGroup(item), "groups don't take refs")

	for _, ref in getRefs(item) do
		if ref.key:lower() == input:lower() then
			return graph.detachRef(doc, id, ref.key)
		end
	end

	assert(input:find(":"), `"{id}" has no ref {input}`)
	local resolved = resolveRef(input, doc.settings.sources)
	return graph.detachRef(doc, id, resolved.ref.key, resolved.ref.kind)
end

-- The canvas comes from the root or the deepest subcommand that names one.
local function requestedCanvas(root: cli.Parser): string?
	local selected: string? = nil
	local current: cli.Parser? = root

	while current do
		selected = current:get("canvas") or selected
		local _, child = current:selected()
		current = child
	end

	return selected
end

local function emitItem(deps: Resolved, doc: Doc, item: Item, asJson: boolean, verb: string)
	if asJson then
		deps.write(json.serialize(render.itemJson(doc, graph.derive(doc), item), true))
	else
		deps.write(`{verb} {item.id} · {graph.label(item)}`)
	end
end

local function sortedTasks(doc: Doc, derived: graph.Derived, keep: (Item) -> boolean): { Item }
	local items: { Item } = {}

	for _, item in doc.nodes do
		if item.type == "task" and keep(item) then
			table.insert(items, item)
		end
	end

	table.sort(items, function(a, b)
		local firstLeverage, secondLeverage = derived.leverage[a.id] or 0, derived.leverage[b.id] or 0

		if firstLeverage ~= secondLeverage then
			return firstLeverage > secondLeverage
		end

		return a.id < b.id
	end)

	return items
end

local function printItems(deps: Resolved, doc: Doc, derived: graph.Derived, items: { Item }, asJson: boolean)
	if asJson then
		local values: json.Array = {}

		for _, item in items do
			table.insert(values, render.itemJson(doc, derived, item))
		end

		deps.write(json.serialize(values, true))
	else
		deps.write(render.table(doc, derived, items))
	end
end

local function insideGroup(doc: Doc, item: Item, groupId: string): boolean
	return table.find(graph.ancestors(doc, item.id), groupId) ~= nil
end

local function isBatchEdit(parser: cli.Parser): boolean
	return #parser:variadics() ~= 1
		or parser:get("where") ~= nil
		or parser:has("dry-run")
		or parser:has("json")
		or parser:get("if-revision") ~= nil
		or parser:has("reconnect")
end

local function editMany(deps: Resolved, dir: string, command: string, parser: cli.Parser, action: string?)
	local ids = parser:variadics()
	local destination = parser:get("to")
	if command == "move" then
		assert(destination or parser:has("top"), "say where with --to <group> or --top")
		assert(not (destination and parser:has("top")), "use --to or --top, not both")
	end
	batchEdit({
		dir = dir,
		action = action or command,
		ids = ids,
		where = parser:get("where"),
		dryRun = parser:has("dry-run"),
		asJson = parser:has("json"),
		ifRevision = requestedRevision(parser),
		destination = if parser:has("top") then nil else destination,
		reconnect = parser:has("reconnect"),
		write = deps.write,
	})
end

local function groupsReport(deps: Resolved, doc: Doc, asJson: boolean)
	local derived = graph.derive(doc)
	local values: json.Array = {}
	local lines = {}

	for _, group in doc.nodes do
		if graph.isGroup(group) then
			table.insert(values, renderGroup.serialize(doc, derived, group))
			table.insert(lines, `{group.id}  {renderGroup.formatLine(doc, derived, group)}`)
		end
	end

	deps.write(if asJson then json.serialize(values, true) else table.concat(lines, "\n"))
end

local function execute(args: { string }, options: Dependencies?)
	local parsers = createParsers()
	parsers.root:parse(args)
	local deps = dependencies(options)
	local names, parser = selectedPath(parsers.root)
	local command = names[1]

	if parsers.root:has("version") then
		deps.write(`orion {getVersion()}`)
		return
	end

	if command == nil or parsers.root:has("help") then
		deps.write(rootHelp(parsers.root))
		return
	end

	if command == "help" then
		local topic = parser:variadics()

		if #topic == 0 then
			deps.write(rootHelp(parsers.root))
			return
		end

		local topicParser, topicHelp = findCommand(parsers.root, topic)
		local name = table.concat(topic, " ")
		deps.write(commandHelp(name, topicHelp, assert(topicParser, `unknown command: {name}`)))
		return
	end

	local helpText = helpFor(parsers.root, names)

	if helpText then
		deps.write(helpText)
		return
	end

	local root = deps.dataDir
	local selected = requestedCanvas(parsers.root)

	local active = store.getActiveWorkspace(root, selected, deps.workspace)
	local dir = store.getWorkspaceDir(root, active)
	local asJson = parser:has("json")

	local commandContext: Context = {
		dir = dir,
		root = root,
		workspace = active,
		requestedWorkspace = selected,
		write = deps.write,
		asJson = asJson,
		runner = deps.runner,
		now = deps.now,
		execute = execute,
	}

	local registered = COMMANDS[command]

	if registered then
		registered.run(assert(parsers.commands[command], `unknown command: {command}`), commandContext)
		return
	end

	local key = table.concat(names, " ")

	-- A noun with subcommands needs one of them.
	if #parser.commands > 0 then
		local choices: { string } = {}

		for _, subcommand in parser.commands do
			table.insert(choices, subcommand.name)
		end

		error(`choose {table.concat(choices, ", ")}`)
	end

	if key == "next" then
		local doc = store.load(dir)
		local derived = graph.derive(doc)
		printItems(
			deps,
			doc,
			derived,
			sortedTasks(doc, derived, function(item)
				local status = derived.status[item.id]
				return not graph.isNote(item) and (status == "ready" or status == "active" or status == "review")
			end),
			asJson
		)
	elseif key == "card list" then
		local doc = store.load(dir)
		local derived = graph.derive(doc)
		local groupId = parser:get("group")

		if groupId then
			groupId = resolveNodeId(doc, groupId)
			graph.group(doc, groupId)
		end

		local all = parser:has("all")
		printItems(
			deps,
			doc,
			derived,
			sortedTasks(doc, derived, function(item)
				return (all or derived.status[item.id] ~= "done")
					and (groupId == nil or insideGroup(doc, item, groupId))
			end),
			asJson
		)
	elseif key == "node query" then
		local doc = store.load(dir)
		local items = selectItems(doc, required(parser, "where"), parser:has("all"))
		local derived = graph.derive(doc)
		if asJson then
			local values: json.Array = {}
			for _, item in items do
				local value = render.itemJson(doc, derived, item)
				if graph.isGroup(item) then
					value.kind = "group"
					value.status = nil
					value.recordedStatus = nil
				end
				table.insert(values, value)
			end
			deps.write(json.serialize(values, true))
		else
			local lines: { string } = {}
			for _, item in items do
				if graph.isGroup(item) or item.type == "image" then
					local kind = if graph.isGroup(item) then "group" else "image"
					local parentItem = if item.parentId then graph.find(doc, item.parentId) else nil
					local where = if parentItem then graph.label(parentItem) else ""
					table.insert(
						lines,
						`{pad(kind, 9)}{pad(item.id, 24)}{pad(graph.label(item), 44)}{pad(kind, 20)}{where}`
					)
				else
					table.insert(lines, render.table(doc, derived, { item }))
				end
			end
			deps.write(if #lines > 0 then table.concat(lines, "\n") else "Nothing matches.")
		end
	elseif key == "node show" then
		local doc = store.load(dir)
		local item = graph.get(doc, resolveNodeId(doc, required(parser, "id")))

		if asJson then
			deps.write(json.serialize(render.itemJson(doc, graph.derive(doc), item), true))
		else
			deps.write(render.show(doc, graph.derive(doc), item))
		end
	elseif key == "card add" then
		local label = joined(parser:variadics(), "<label>")
		local added: Item
		local options = fields(parser) :: graph.AddOptions
		local group = parser:get("group")
		local doc = store.transaction(dir, function(doc)
			options.group = if group then resolveNodeId(doc, group) else nil
			added = graph.addItem(doc, label, options)
			attachRef(doc, added.id, parser:get("ref"))
		end)

		emitItem(deps, doc, added, asJson, "Added")
	elseif key == "card set" then
		local id = required(parser, "id")
		local values = fields(parser)
		local changed: Item
		local doc = store.transaction(dir, function(doc)
			requireItem(doc, id)
			changed = graph.setFields(doc, id, values)
			attachRef(doc, id, parser:get("ref"))
		end)

		emitItem(deps, doc, changed, asJson, "Updated")
	elseif key == "card done" then
		local ids = parser:variadics()
		if isBatchEdit(parser) then
			editMany(deps, dir, "done", parser)
		else
			local id = ids[1]
			local doc = store.transaction(dir, function(doc)
				requireItem(doc, id)
				graph.setFields(doc, id, { status = "done" })
			end)

			deps.write(`Done: {id} · {graph.label(graph.get(doc, id))}`)
		end
	elseif key == "card import" then
		importCommand.run(parser, commandContext)
	elseif key == "note add" then
		local text = joined(parser:variadics(), "<text>")
		local added: Item
		local group = parser:get("group")
		local doc = store.transaction(dir, function(doc)
			added = graph.addNote(doc, text, {
				group = if group then resolveNodeId(doc, group) else nil,
				after = parser:get("after"),
				before = parser:get("before"),
			})
		end)

		emitItem(deps, doc, added, asJson, "Added note")
	elseif key == "link add" then
		local from, to = required(parser, "from"), required(parser, "to")
		local kind = if parser:has("related") then "related" else "blocks"
		local ids = { from, to }
		for _, id in parser:variadics() do
			table.insert(ids, id)
		end
		local dryRun = parser:has("dry-run")
		local doc, baseRevision = runEdit(dir, dryRun, requestedRevision(parser), function(current)
			for index = 1, #ids - 1 do
				graph.link(current, ids[index], ids[index + 1], kind)
			end
		end)

		if asJson then
			local links: json.Array = {}
			local items: json.Array = {}
			for _, id in ids do
				table.insert(items, json.object({ id = id, label = graph.label(graph.get(doc, id)) }))
			end
			for index = 1, #ids - 1 do
				table.insert(links, json.object({ from = ids[index], to = ids[index + 1], kind = kind }))
			end
			deps.write(json.serialize(
				json.object({
					action = "link",
					dryRun = dryRun,
					baseRevision = baseRevision,
					revision = doc.revision,
					items = items,
					links = links,
				}),
				true
			))
		elseif #ids == 2 and not dryRun then
			deps.write(if kind == "blocks" then `{to} now waits on {from}` else `{from} and {to} are related`)
		else
			local count = #ids - 1
			local revision = if dryRun then `{baseRevision}` else `{baseRevision} → {doc.revision}`
			local lines = {
				`{if dryRun then "Would link" else "Linked"} {count} {if count == 1 then "pair" else "pairs"} at revision {revision}`,
			}
			for index = 1, count do
				table.insert(lines, `  {ids[index]} → {ids[index + 1]} ({kind})`)
			end
			deps.write(table.concat(lines, "\n"))
		end
	elseif key == "link insert" then
		local id, from = required(parser, "id"), required(parser, "between")
		local targets = parser:variadics()
		assert(#targets == 1, "insert needs exactly one target after --between <from>")
		local to = targets[1]
		local dryRun = parser:has("dry-run")
		local doc, baseRevision = runEdit(dir, dryRun, requestedRevision(parser), function(current)
			graph.insertBetween(current, id, from, to)
		end)
		if asJson then
			deps.write(json.serialize(
				json.object({
					action = "insert",
					dryRun = dryRun,
					baseRevision = baseRevision,
					revision = doc.revision,
					items = { json.object({ id = id, label = graph.label(graph.get(doc, id)) }) },
					from = from,
					to = to,
				}),
				true
			))
		else
			local revision = if dryRun then `{baseRevision}` else `{baseRevision} → {doc.revision}`
			deps.write(
				`{if dryRun then "Would insert" else "Inserted"} {id} between {from} and {to} at revision {revision}`
			)
		end
	elseif key == "link remove" then
		local from, to = required(parser, "from"), required(parser, "to")
		store.transaction(dir, function(doc)
			graph.unlink(doc, from, to)
		end)

		deps.write(`Removed the link from {from} to {to}`)
	elseif key == "node remove" then
		local ids = parser:variadics()
		if isBatchEdit(parser) then
			editMany(deps, dir, "remove", parser)
		else
			local id = ids[1]
			store.transaction(dir, function(doc)
				graph.remove(doc, resolveNodeId(doc, id))
			end)

			deps.write(`Removed {id}`)
		end
	elseif key == "node move" then
		local ids = parser:variadics()
		if isBatchEdit(parser) then
			editMany(deps, dir, "move", parser)
		else
			local id = ids[1]
			local to = parser:get("to")
			assert(to or parser:has("top"), "say where with --to <group> or --top")
			store.transaction(dir, function(doc)
				graph.move(
					doc,
					resolveNodeId(doc, id),
					if parser:has("top") then nil else resolveNodeId(doc, to :: string)
				)
			end)

			deps.write(`Moved {id} to {to or "the top level"}`)
		end
	elseif key == "group list" then
		groupsReport(deps, store.load(dir), asJson)
	elseif key == "group create" then
		local label = joined(parser:variadics(), "<label>")
		local parent = parser:get("in")
		local made: Item
		local doc = store.transaction(dir, function(doc)
			made = graph.createGroup(doc, label, if parent then resolveNodeId(doc, parent) else nil)
		end)

		emitItem(deps, doc, made, asJson, "Created group")
	elseif key == "group add" then
		local label = joined(parser:variadics(), "<label>")
		local items = parseCommaList(required(parser, "items"))
		local made: Item
		local doc = store.transaction(dir, function(doc)
			local ids = {}
			for _, item in items do
				table.insert(ids, resolveNodeId(doc, item))
			end
			made = graph.makeGroup(doc, label, ids)
		end)

		emitItem(deps, doc, made, asJson, "Grouped into")
	elseif key == "group remove" then
		editMany(deps, dir, "group", parser, "removeGroup")
	elseif key == "group set" then
		local id = required(parser, "id")
		local values = fields(parser)
		checkStyleAssets(dir, values.cover)
		checkStyleAssets(dir, values.background)
		local changed: Item
		local doc = store.transaction(dir, function(doc)
			local groupId = resolveNodeId(doc, id)
			requireGroup(doc, groupId)
			changed = graph.setFields(doc, groupId, values)
		end)

		emitItem(deps, doc, changed, asJson, "Updated")
	elseif key == "group ungroup" then
		local ids = parser:variadics()
		if isBatchEdit(parser) then
			editMany(deps, dir, "ungroup", parser)
		else
			local id = ids[1]
			store.transaction(dir, function(doc)
				graph.ungroup(doc, resolveNodeId(doc, id))
			end)

			deps.write(`Ungrouped {id}`)
		end
	elseif key == "group tidy" then
		tidy.run(parser, commandContext)
	elseif key == "ref remove" then
		local id = required(parser, "id")
		local input = required(parser, "ref")
		local detached: Item
		local doc = store.transaction(dir, function(doc)
			detached = detachRef(doc, id, input)
		end)

		emitItem(deps, doc, detached, asJson, "Updated")
	elseif key == "sync" then
		local dryRun = parser:has("dry-run")
		local report: RefreshReport

		local snapshot = store.load(dir)
		local apply = assert(getAdapter("github").refresh)(
			snapshot,
			deps.runner,
			{ discover = parser:has("discover"), now = deps.now() }
		)

		if dryRun then
			report = apply(snapshot)
		else
			store.transaction(dir, function(doc)
				report = apply(doc)
			end)
		end

		if asJson then
			deps.write(json.serialize(report :: any, true))
		else
			deps.write(`{formatRefreshReport(report, dryRun)}\n{SYNC_DEPRECATION}`)
		end
	end
end

-- Lute passes the program path as the first argument.
local function run(argv: { string })
	local succeeded, message = pcall(execute, { table.unpack(argv, 2) }, nil)

	if not succeeded then
		local text = tostring(message):gsub("^[^\n]-:%d+: ", "", 1)
		print(`Error: {text}`)
		process.exit(1)
	end
end

-- Describes every command and option, for the generated reference in docs/.
local function describe(): describeCommands.CommandDescription
	return describeCommands(createParsers().root, "orion", SUMMARY)
end

return table.freeze({
	describe = describe,
	execute = execute,
	run = run,
})
