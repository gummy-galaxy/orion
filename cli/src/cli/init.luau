local cli = require("@batteries/cli")
local json = require("@std/json")
local process = require("@std/process")

local backups = require("@root/cli/backups")
local batchEdit = require("@root/cli/batchEdit")
local check = require("@root/cli/check")
local checkStyleAssets = require("@root/style/checkStyleAssets")
local context = require("@root/cli/context")
local defaultRun = require("@root/command")
local describeCommands = require("@root/cli/describeCommands")
local focus = require("@root/cli/focus")
local formatRefreshReport = require("@root/github/formatRefreshReport")
local getAdapter = require("@root/adapters/getAdapter")
local getErrorText = require("@root/getErrorText")
local getRefs = require("@root/refs/getRefs")
local githubTypes = require("@root/github/types")
local graph = require("@root/graph")
local importCommand = require("@root/cli/import")
local ingest = require("@root/cli/ingest")
local mcp = require("@root/cli/mcp")
local media = require("@root/cli/media")
local pad = require("@root/render/pad")
local parseCommaList = require("@root/cli/parseCommaList")
local render = require("@root/render")
local renderGroup = require("@root/render/group")
local requestedRevision = require("@root/cli/requestedRevision")
local resolveRef = require("@root/adapters/resolveRef")
local restore = require("@root/cli/restore")
local runEdit = require("@root/cli/runEdit")
local selectItems = require("@root/query/selectItems")
local serve = require("@root/cli/serve")
local source = require("@root/cli/source")
local store = require("@root/store")
local suggest = require("@root/cli/suggest")
local suggestions = require("@root/cli/suggestions")
local tidy = require("@root/cli/tidy")
local types = require("@root/types")
local workspace = require("@root/cli/workspace")

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

local COMMANDS: { [string]: Command } = {
	backups = backups,
	focus = focus,
	mcp = mcp,
	media = media,
	restore = restore,
	serve = serve,
	suggest = suggest,
	suggestions = suggestions,
	workspace = workspace,
	source = source,
	ingest = ingest,
	check = check,
	tidy = tidy,
	import = importCommand,
}

local COMMAND_HELP: { [string]: string } = {
	list = "List work items with their derived status",
	query = "Find cards and groups with an expression",
	ready = "List items that can start now, most unblocking first",
	groups = "List groups with their progress",
	show = "Show one item or group",
	add = "Add a work item",
	set = "Change an item's or group's fields",
	done = "Mark one or more items done",
	link = "Link each adjacent pair of items",
	insert = "Insert an item into an existing link",
	unlink = "Remove the link between two items",
	note = "Add a note, optionally between two linked items",
	remove = "Remove items; optionally reconnect a card's links",
	group = "Make a group around items, or remove one with everything inside",
	ref = "Take outside work off an item",
	ungroup = "Dissolve groups, keeping their items in place",
	move = "Move items or groups into another group",
	sync = "Update pull request items from GitHub (deprecated: use ingest)",
	matches = "List unplaced pull requests and likely cards",
	path = "Print where Orion keeps its data",
	help = "Show help for Orion or one of its commands",
}

local ABOUT = [[
Statuses: todo, active, review, blocked, deferred, done.
  Listed statuses are derived: todo shows as ready once nothing it waits on is open,
  and as blocked while something is. Notes pass blocking through and never count as work.
Repositories are "owner/name".
Data lives in Orion's user data folder (run orion path to see it); set ORION_DATA_DIR to change it.
The Orion app talks to orion serve, which watches the data files.
Use orion serve status [--json] to find the running server.
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

local function addWorkspaceOption(parser: cli.Parser)
	parser:add("workspace", "option", { help = "Use this workspace for this command" })
end

local function addRefOption(parser: cli.Parser)
	parser:add("ref", "option", {
		help = "Attach outside work: a GitHub or Jira URL, source:key such as jira:ABC-1, or branch:owner/name@branch",
	})
end

-- Item fields. Set passes a suffix to say that groups don't take them.
local function addFieldOptions(parser: cli.Parser, suffix: string)
	parser:add("status", "option", { help = `todo, active, review, blocked, deferred, or done{suffix}` })
	parser:add(
		"repo",
		"option",
		{ help = `Repository, as owner/name. Deprecated: with --pr, use --ref with the pull request URL{suffix}` }
	)
	parser:add(
		"pr",
		"option",
		{ help = `Pull request number. Deprecated: use --ref with the pull request URL{suffix}` }
	)
	parser:add("who", "option", { help = `Whose move: you, review, or ci (empty to clear){suffix}` })
	parser:add("note", "option", { help = `Free-form note (empty to clear){suffix}` })
	parser:add("kind", "option", { help = `step, or gate for one that's done once everything it waits on is{suffix}` })
end

type Parsers = {
	root: cli.Parser,
	commands: { [string]: cli.Parser },
}

local function createParsers(): Parsers
	local root = cli.parser()
	addHelpFlag(root)
	addWorkspaceOption(root)
	local commands: { [string]: cli.Parser } = {}

	local function command(name: string): cli.Parser
		local registered = COMMANDS[name]
		local parser = root:subcommand(name, { help = if registered then registered.help else COMMAND_HELP[name] })
		addHelpFlag(parser)
		addWorkspaceOption(parser)
		commands[name] = parser
		return parser
	end

	local function registeredCommand(name: string)
		COMMANDS[name].define(command(name))
	end

	local list = command("list")
	list:add("group", "option", { help = "Only items inside this group" })
	list:add("all", "flag", { help = "Include done items" })
	addJsonFlag(list)

	local query = command("query")
	query:add("where", "option", { help = "Expression selecting cards or groups", required = true })
	query:add("all", "flag", { help = "Include done items" })
	addJsonFlag(query)

	addJsonFlag(command("ready"))
	addJsonFlag(command("groups"))

	local show = command("show")
	show:add("id", "positional", { help = "Item or group id" })
	addJsonFlag(show)

	registeredCommand("focus")

	local add = command("add")
	add:add("label", "variadic", { help = "What the work is" })
	add:add("group", "option", { help = "Group to add it to" })
	addFieldOptions(add, "")
	addRefOption(add)
	addJsonFlag(add)

	local set = command("set")
	set:add("id", "positional", { help = "Item or group id" })
	set:add("label", "option", { help = "New label" })
	set:add("blurb", "option", { help = "Group description (groups only)" })
	set:add("arrange", "option", { help = "How reflow arranges a group: auto or custom (groups only)" })
	set:add(
		"cover",
		"option",
		{ help = "Image asset id for the cover, from orion media insert --json (groups only; empty to clear)" }
	)
	set:add(
		"background",
		"option",
		{ help = "Color, color token such as card.background, or image asset id (groups only; empty to clear)" }
	)
	addFieldOptions(set, " (items only)")
	addRefOption(set)
	addJsonFlag(set)

	local function addBatchOptions(parser: cli.Parser, help: string)
		parser:add("ids", "variadic", { help = help })
		parser:add("where", "option", { help = "Select targets with an expression instead of ids" })
		parser:add("dry-run", "flag", { help = "Preview changes and current revision without writing" })
		parser:add("if-revision", "option", { help = "Write only if the document has this revision" })
		addJsonFlag(parser)
	end

	addBatchOptions(command("done"), "Item ids")

	local link = command("link")
	link:add("from", "positional", { help = "The item that has to happen first" })
	link:add("to", "positional", { help = "The item that waits on it" })
	link:add("next", "variadic", { help = "Further items in the chain" })
	link:add("related", "flag", { help = "Link without blocking" })
	link:add("dry-run", "flag", { help = "Preview changes and current revision without writing" })
	link:add("if-revision", "option", { help = "Write only if the document has this revision" })
	addJsonFlag(link)

	local insert = command("insert")
	insert:add("id", "positional", { help = "Item to place in the link" })
	insert:add("between", "option", { help = "Source item whose link is replaced", required = true })
	insert:add("target", "variadic", { help = "Target item whose link is replaced" })
	insert:add("dry-run", "flag", { help = "Preview changes and current revision without writing" })
	insert:add("if-revision", "option", { help = "Write only if the document has this revision" })
	addJsonFlag(insert)

	local unlink = command("unlink")
	unlink:add("from", "positional", { help = "Link source" })
	unlink:add("to", "positional", { help = "Link target" })

	local note = command("note")
	note:add("text", "variadic", { help = "Note text" })
	note:add("group", "option", { help = "Group to add it to" })
	note:add("after", "option", { help = "Item the note follows" })
	note:add("before", "option", { help = "Item the note leads into" })
	addJsonFlag(note)

	local remove = command("remove")
	addBatchOptions(remove, "Item ids")
	remove:add("reconnect", "flag", { help = "Reconnect at most one incoming and outgoing link per item" })

	local group = command("group")
	local function groupSubcommand(name: string, help: string): cli.Parser
		local parser = group:subcommand(name, { help = help })
		addHelpFlag(parser)
		addWorkspaceOption(parser)
		return parser
	end

	local groupAdd = groupSubcommand("add", "Wrap items that share a parent in a new group")
	groupAdd:add("label", "variadic", { help = "Group name" })
	groupAdd:add("items", "option", { help = "Comma-separated ids to put in it", required = true })
	addJsonFlag(groupAdd)
	addBatchOptions(groupSubcommand("remove", "Remove groups with everything inside them"), "Group ids")

	local ref = command("ref")
	local refRemove = ref:subcommand("remove", { help = "Take a ref off an item" })
	addHelpFlag(refRemove)
	addWorkspaceOption(refRemove)
	refRemove:add("id", "positional", { help = "Item id" })
	refRemove:add(
		"ref",
		"positional",
		{ help = "The ref's key as orion show lists it, such as owner/name#12, or a URL or source:key" }
	)
	addJsonFlag(refRemove)

	addBatchOptions(command("ungroup"), "Group ids")

	local move = command("move")
	addBatchOptions(move, "Item or group ids")
	move:add("to", "option", { help = "Destination group" })
	move:add("top", "flag", { help = "Move to the top level" })

	local sync = command("sync")
	sync:add("discover", "flag", { help = "Add your open pull requests that aren't on the canvas to an Inbox group" })
	sync:add("dry-run", "flag", { help = "Show what would change without writing" })
	addJsonFlag(sync)

	addJsonFlag(command("matches"))
	registeredCommand("backups")
	registeredCommand("media")
	registeredCommand("restore")
	registeredCommand("serve")
	registeredCommand("source")
	registeredCommand("ingest")
	registeredCommand("import")

	registeredCommand("suggest")
	registeredCommand("suggestions")
	registeredCommand("check")
	registeredCommand("tidy")

	command("path")
	registeredCommand("mcp")
	registeredCommand("workspace")
	command("help"):add("command", "positional", { help = "Command to describe" })

	return { root = root, commands = commands }
end

local function rootHelp(parser: cli.Parser): string
	return table.concat({ SUMMARY, "", parser:usage("orion"), "", parser:help(), "", ABOUT }, "\n")
end

local function commandHelp(name: string, parser: cli.Parser): string
	local registered = COMMANDS[name]
	local help = if registered then registered.help else COMMAND_HELP[name]
	local syntax = if name == "query" then `\n\n{QUERY_HELP}` else ""
	return `{help}\n\n{parser:usage(`orion {name}`)}\n\n{parser:help()}{syntax}`
end

local function dependencies(options: Dependencies?): Resolved
	local given: Dependencies = options or {}
	return {
		runner = given.runner or defaultRun,
		write = given.write or print,
		dataDir = given.dataDir or store.defaultDir(),
		workspace = if given.workspace == nil then process.env.ORION_WORKSPACE else given.workspace,
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

-- Attaches the --ref given to add or set, resolving it against the document's sources.
local function attachRef(doc: Doc, id: string, input: string?)
	if input then
		graph.attachRef(doc, id, resolveRef(input, doc.settings.sources))
	end
end

-- Takes a ref off an item by the key orion show lists. A URL or source:key that isn't a key on the item resolves
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

-- `orion group <label> --items` predates `group add`, so a group command without a subcommand still means add.
local function withGroupAdd(args: { string }): { string }
	local index = 1

	while index <= #args do
		local arg = args[index]

		if arg == "--workspace" then
			index += 2
		elseif arg:sub(1, 1) == "-" then
			index += 1
		else
			break
		end
	end

	local following = args[index + 1]
	local isSubcommand = following == "add" or following == "remove"
	local wantsHelp = following == nil or following == "--help" or following == "-h"

	if args[index] ~= "group" or isSubcommand or wantsHelp then
		return args
	end

	local rewritten = table.clone(args)
	table.insert(rewritten, index + 1, "add")
	return rewritten
end

-- The workspace comes from the root or the deepest subcommand that names one.
local function requestedWorkspace(root: cli.Parser): string?
	local selected: string? = nil
	local current: cli.Parser? = root

	while current do
		selected = current:get("workspace") or selected
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
			table.insert(values, renderGroup.serialize(derived, group))
			table.insert(lines, `{group.id}  {renderGroup.formatLine(derived, group)}`)
		end
	end

	deps.write(if asJson then json.serialize(values, true) else table.concat(lines, "\n"))
end

local function execute(args: { string }, options: Dependencies?)
	local parsers = createParsers()
	parsers.root:parse(withGroupAdd(args))
	local deps = dependencies(options)

	local command, parser = parsers.root:selected()

	if command == "help" and parser then
		local topic = parser:get("command")

		if topic then
			local topicParser = assert(parsers.commands[topic], `unknown command: {topic}`)
			deps.write(commandHelp(topic, topicParser))
			return
		end
	end

	if command == nil or parser == nil or command == "help" or parsers.root:has("help") then
		deps.write(rootHelp(parsers.root))
		return
	end

	if parser:has("help") then
		deps.write(commandHelp(command, parser))
		return
	end

	local subcommandName, subparser = parser:selected()

	if subcommandName and subparser and subparser:has("help") then
		deps.write(
			`{command} {subcommandName}\n\n{subparser:usage(`orion {command} {subcommandName}`)}\n\n{subparser:help()}`
		)
		return
	end

	local root = deps.dataDir
	local selected = requestedWorkspace(parsers.root)

	local active = store.getActiveWorkspace(root, selected, deps.workspace)
	local dir = store.getWorkspaceDir(root, active)
	local asJson = parser:has("json")
	local registered = COMMANDS[command]

	if registered then
		registered.run(parser, {
			dir = dir,
			root = root,
			workspace = active,
			requestedWorkspace = selected,
			write = deps.write,
			asJson = asJson,
			runner = deps.runner,
			now = deps.now,
			execute = execute,
		})
		return
	end

	if command == "path" then
		deps.write(dir)
	elseif command == "list" then
		local doc = store.load(dir)
		local derived = graph.derive(doc)
		local groupId = parser:get("group")

		if groupId then
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
	elseif command == "query" then
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
					local parent = if item.parentId then graph.find(doc, item.parentId) else nil
					local where = if parent then graph.label(parent) else ""
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
	elseif command == "ready" then
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
	elseif command == "groups" then
		groupsReport(deps, store.load(dir), asJson)
	elseif command == "matches" then
		local doc = store.load(dir)
		local unplaced = if doc.github then json.asArray(doc.github.unplaced) else nil
		local values: json.Array = unplaced or {}

		if asJson then
			deps.write(json.serialize(values, true))
		else
			local lines: { string } = {}

			for _, raw in values do
				local pull = json.asObject(raw)

				if not pull then
					continue
				end

				table.insert(lines, `{pull.repo}#{pull.number}  {pull.title}`)

				for _, entry in json.asArray(pull.matches) or {} do
					local candidate = json.asObject(entry)

					if candidate then
						local item = if type(candidate.id) == "string" then graph.find(doc, candidate.id) else nil
						table.insert(
							lines,
							`  {candidate.id}  {if item then graph.label(item) else ""}  {candidate.score}`
						)
					end
				end
			end

			deps.write(if #lines > 0 then table.concat(lines, "\n") else "No unplaced pull requests.")
		end
	elseif command == "show" then
		local doc = store.load(dir)
		local item = graph.get(doc, required(parser, "id"))

		if asJson then
			deps.write(json.serialize(render.itemJson(doc, graph.derive(doc), item), true))
		else
			deps.write(render.show(doc, graph.derive(doc), item))
		end
	elseif command == "add" then
		local label = joined(parser:variadics(), "<label>")
		local added: Item
		local options = fields(parser) :: graph.AddOptions
		options.group = parser:get("group")
		local doc = store.transaction(dir, function(doc)
			added = graph.addItem(doc, label, options)
			attachRef(doc, added.id, parser:get("ref"))
		end)

		emitItem(deps, doc, added, asJson, "Added")
	elseif command == "set" then
		local id = required(parser, "id")
		local values = fields(parser)
		checkStyleAssets(dir, values.cover)
		checkStyleAssets(dir, values.background)
		local changed: Item
		local doc = store.transaction(dir, function(doc)
			changed = graph.setFields(doc, id, values)
			attachRef(doc, id, parser:get("ref"))
		end)

		emitItem(deps, doc, changed, asJson, "Updated")
	elseif command == "done" then
		local ids = parser:variadics()
		if isBatchEdit(parser) then
			editMany(deps, dir, command, parser)
		else
			local id = ids[1]
			local doc = store.transaction(dir, function(doc)
				graph.setFields(doc, id, { status = "done" })
			end)

			deps.write(`Done: {id} · {graph.label(graph.get(doc, id))}`)
		end
	elseif command == "link" then
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
	elseif command == "insert" then
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
	elseif command == "unlink" then
		local from, to = required(parser, "from"), required(parser, "to")
		store.transaction(dir, function(doc)
			graph.unlink(doc, from, to)
		end)

		deps.write(`Removed the link from {from} to {to}`)
	elseif command == "note" then
		local text = joined(parser:variadics(), "<text>")
		local added: Item
		local doc = store.transaction(dir, function(doc)
			added = graph.addNote(
				doc,
				text,
				{ group = parser:get("group"), after = parser:get("after"), before = parser:get("before") }
			)
		end)

		emitItem(deps, doc, added, asJson, "Added note")
	elseif command == "remove" then
		local ids = parser:variadics()
		if isBatchEdit(parser) then
			editMany(deps, dir, command, parser)
		else
			local id = ids[1]
			store.transaction(dir, function(doc)
				graph.remove(doc, id)
			end)

			deps.write(`Removed {id}`)
		end
	elseif command == "group" then
		assert(subcommandName and subparser, "choose add or remove")

		if subcommandName == "remove" then
			editMany(deps, dir, command, subparser, "removeGroup")
		else
			local label = joined(subparser:variadics(), "<label>")
			local ids = parseCommaList(required(subparser, "items"))
			local made: Item
			local doc = store.transaction(dir, function(doc)
				made = graph.makeGroup(doc, label, ids)
			end)

			emitItem(deps, doc, made, subparser:has("json"), "Grouped into")
		end
	elseif command == "ref" then
		assert(subcommandName and subparser, "choose remove")
		local id = required(subparser, "id")
		local input = required(subparser, "ref")
		local detached: Item
		local doc = store.transaction(dir, function(doc)
			detached = detachRef(doc, id, input)
		end)

		emitItem(deps, doc, detached, subparser:has("json"), "Updated")
	elseif command == "ungroup" then
		local ids = parser:variadics()
		if isBatchEdit(parser) then
			editMany(deps, dir, command, parser)
		else
			local id = ids[1]
			store.transaction(dir, function(doc)
				graph.ungroup(doc, id)
			end)

			deps.write(`Ungrouped {id}`)
		end
	elseif command == "move" then
		local ids = parser:variadics()
		if isBatchEdit(parser) then
			editMany(deps, dir, command, parser)
		else
			local id = ids[1]
			local to = parser:get("to")
			assert(to or parser:has("top"), "say where with --to <group> or --top")
			store.transaction(dir, function(doc)
				graph.move(doc, id, if parser:has("top") then nil else to)
			end)

			deps.write(`Moved {id} to {to or "the top level"}`)
		end
	elseif command == "sync" then
		local dryRun = parser:has("dry-run")
		local report: RefreshReport

		if dryRun then
			report = assert(getAdapter("github").refresh)(
				store.load(dir),
				deps.runner,
				{ discover = parser:has("discover"), now = deps.now() }
			)
		else
			store.transaction(dir, function(doc)
				report = assert(getAdapter("github").refresh)(
					doc,
					deps.runner,
					{ discover = parser:has("discover"), now = deps.now() }
				)
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
		print(`Error: {getErrorText(message)}`)
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
