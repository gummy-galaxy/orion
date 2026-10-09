local cli = require("@batteries/cli")
local json = require("@std/json")
local process = require("@std/process")

local backups = require("@root/cli/backups")
local context = require("@root/cli/context")
local defaultRun = require("@root/command")
local focus = require("@root/cli/focus")
local github = require("@root/github")
local graph = require("@root/graph")
local ingest = require("@root/cli/ingest")
local mcp = require("@root/cli/mcp")
local media = require("@root/cli/media")
local parseCommaList = require("@root/cli/parseCommaList")
local render = require("@root/render")
local renderGroup = require("@root/render/group")
local restore = require("@root/cli/restore")
local serve = require("@root/cli/serve")
local source = require("@root/cli/source")
local store = require("@root/store")
local suggest = require("@root/cli/suggest")
local suggestions = require("@root/cli/suggestions")
local types = require("@root/types")
local workspace = require("@root/cli/workspace")

type Doc = types.Doc
type Item = types.Item
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
}

local COMMAND_HELP: { [string]: string } = {
	list = "List work items with their derived status",
	ready = "List items that can start now, most unblocking first",
	groups = "List groups with their progress",
	show = "Show one item or group",
	add = "Add a work item",
	set = "Change an item's or group's fields",
	done = "Mark an item done",
	link = "Make one item wait on another",
	unlink = "Remove the link between two items",
	note = "Add a note, optionally between two linked items",
	remove = "Remove an item; a note's links are reconnected",
	group = "Wrap items that share a parent in a new group",
	ungroup = "Dissolve a group, keeping its items in place",
	move = "Move an item or group into another group",
	sync = "Update pull request items from GitHub",
	matches = "List unplaced pull requests and likely cards",
	path = "Print where Orion keeps its data",
	help = "Show help for Orion or one of its commands",
}

local ABOUT = [[
Statuses: todo, active, review, blocked, deferred, done.
  Listed statuses are derived: todo shows as ready once nothing it waits on is open,
  and as blocked while something is. Notes pass blocking through and never count as work.
Repositories are "name" under the default owner (flipbook-labs) or "owner/name".
Data lives in Orion's user data folder (run orion path to see it); set ORION_DATA_DIR to change it.
The Orion app talks to orion serve, which watches the data files.
While the app is open, orion focus shows its open group and selection.]]

local function addHelpFlag(parser: cli.Parser)
	parser:add("help", "flag", { help = "Show this help", aliases = { "h" } })
end

local function addJsonFlag(parser: cli.Parser)
	parser:add("json", "flag", { help = "Print JSON" })
end

local function addWorkspaceOption(parser: cli.Parser)
	parser:add("workspace", "option", { help = "Use this workspace for this command" })
end

local function addFieldOptions(parser: cli.Parser)
	parser:add("status", "option", { help = "todo, active, review, blocked, deferred, or done" })
	parser:add("repo", "option", { help = "Repository, as name or owner/name" })
	parser:add("pr", "option", { help = "Pull request number" })
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

	addJsonFlag(command("ready"))
	addJsonFlag(command("groups"))

	local show = command("show")
	show:add("id", "positional", { help = "Item or group id" })
	addJsonFlag(show)

	registeredCommand("focus")

	local add = command("add")
	add:add("label", "variadic", { help = "What the work is" })
	add:add("group", "option", { help = "Group to add it to" })
	addFieldOptions(add)
	addJsonFlag(add)

	local set = command("set")
	set:add("id", "positional", { help = "Item or group id" })
	set:add("label", "option", { help = "New label" })
	set:add("blurb", "option", { help = "Group description" })
	set:add("arrange", "option", { help = "How reflow arranges a group: auto or custom" })
	addFieldOptions(set)
	addJsonFlag(set)

	command("done"):add("id", "positional", { help = "Item id" })

	local link = command("link")
	link:add("from", "positional", { help = "The item that has to happen first" })
	link:add("to", "positional", { help = "The item that waits on it" })
	link:add("related", "flag", { help = "Link without blocking" })

	local unlink = command("unlink")
	unlink:add("from", "positional", { help = "Link source" })
	unlink:add("to", "positional", { help = "Link target" })

	local note = command("note")
	note:add("text", "variadic", { help = "Note text" })
	note:add("group", "option", { help = "Group to add it to" })
	note:add("after", "option", { help = "Item the note follows" })
	note:add("before", "option", { help = "Item the note leads into" })
	addJsonFlag(note)

	command("remove"):add("id", "positional", { help = "Item id" })

	local group = command("group")
	group:add("label", "variadic", { help = "Group name" })
	group:add("items", "option", { help = "Comma-separated ids to put in it", required = true })
	addJsonFlag(group)

	command("ungroup"):add("id", "positional", { help = "Group id" })

	local move = command("move")
	move:add("id", "positional", { help = "Item or group id" })
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

	registeredCommand("suggest")
	registeredCommand("suggestions")

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
	return `{help}\n\n{parser:usage(`orion {name}`)}\n\n{parser:help()}`
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

local function syncReport(report: github.Report, dryRun: boolean): string
	local lines = { `{if dryRun then "Would update" else "Checked"} {report.checked} pull requests on GitHub.` }

	for _, change in report.changes do
		local who = if change.fromWho ~= change.toWho
			then ` (move: {change.fromWho or "unset"} → {change.toWho or "unset"})`
			else ""
		local closed = if change.closed then " — closed without merging; deferred until you decide" else ""
		table.insert(lines, `  {change.id}: {change.fromStatus} → {change.toStatus}{who}{closed}`)
	end

	if #report.changes == 0 and #report.added == 0 and #report.linked == 0 and #report.unlinked == 0 then
		table.insert(lines, "  Everything already matches.")
	end

	for _, link in report.linked do
		table.insert(lines, `  linked {link.from} → {link.to} (stacked)`)
	end

	for _, link in report.unlinked do
		table.insert(lines, `  unlinked {link.from} → {link.to} (stacked)`)
	end

	for _, id in report.added do
		table.insert(lines, `  added {id} to Inbox`)
	end

	if #report.missing > 0 then
		table.insert(lines, `  not found on GitHub: {table.concat(report.missing, ", ")}`)
	end

	return table.concat(lines, "\n")
end

local function execute(args: { string }, options: Dependencies?)
	local parsers = createParsers()
	parsers.root:parse(args)
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
	local selected = parser:get("workspace") or parsers.root:get("workspace")

	if subparser then
		selected = subparser:get("workspace") or selected
	end

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
		end)

		emitItem(deps, doc, added, asJson, "Added")
	elseif command == "set" then
		local id = required(parser, "id")
		local changed: Item
		local doc = store.transaction(dir, function(doc)
			changed = graph.setFields(doc, id, fields(parser))
		end)

		emitItem(deps, doc, changed, asJson, "Updated")
	elseif command == "done" then
		local id = required(parser, "id")
		local doc = store.transaction(dir, function(doc)
			graph.setFields(doc, id, { status = "done" })
		end)

		deps.write(`Done: {id} · {graph.label(graph.get(doc, id))}`)
	elseif command == "link" then
		local from, to = required(parser, "from"), required(parser, "to")
		local kind = if parser:has("related") then "related" else "blocks"
		store.transaction(dir, function(doc)
			graph.link(doc, from, to, kind)
		end)

		deps.write(if kind == "blocks" then `{to} now waits on {from}` else `{from} and {to} are related`)
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
		local id = required(parser, "id")
		store.transaction(dir, function(doc)
			graph.remove(doc, id)
		end)

		deps.write(`Removed {id}`)
	elseif command == "group" then
		local label = joined(parser:variadics(), "<label>")
		local ids = parseCommaList(parser:get("items") or "")
		local made: Item
		local doc = store.transaction(dir, function(doc)
			made = graph.makeGroup(doc, label, ids)
		end)

		emitItem(deps, doc, made, asJson, "Grouped into")
	elseif command == "ungroup" then
		local id = required(parser, "id")
		store.transaction(dir, function(doc)
			graph.ungroup(doc, id)
		end)

		deps.write(`Ungrouped {id}`)
	elseif command == "move" then
		local id = required(parser, "id")
		local to = parser:get("to")
		assert(to or parser:has("top"), "say where with --to <group> or --top")
		store.transaction(dir, function(doc)
			graph.move(doc, id, if parser:has("top") then nil else to)
		end)

		deps.write(`Moved {id} to {to or "the top level"}`)
	elseif command == "sync" then
		local dryRun = parser:has("dry-run")
		local fetched = github.collect(store.load(dir), deps.runner, parser:has("discover"))
		local report: github.Report

		if dryRun then
			report = github.apply(store.load(dir), fetched, deps.now())
		else
			store.transaction(dir, function(doc)
				report = github.apply(doc, fetched, deps.now())
			end)
		end

		if asJson then
			deps.write(json.serialize(report :: any, true))
		else
			deps.write(syncReport(report, dryRun))
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

return table.freeze({
	execute = execute,
	run = run,
})
