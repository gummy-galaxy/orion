local batteriesCli = require("@batteries/cli")
local fs = require("@std/fs")
local json = require("@std/json")
local process = require("@std/process")

local defaultRun = require("@root/command")
local github = require("@root/github")
local graph = require("@root/graph")
local ingest = require("@root/ingest")
local render = require("@root/render")
local sources = require("@root/sources")
local store = require("@root/store")
local suggest = require("@root/suggest")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item

export type Dependencies = {
	runner: types.CommandRunner?,
	write: ((string) -> ())?,
	dataDir: string?,
	now: (() -> string)?,
	-- Stands in for ORION_WORKSPACE; "" means unset.
	workspace: string?,
}

type Resolved = {
	runner: types.CommandRunner,
	write: (string) -> (),
	dataDir: string,
	now: () -> string,
	workspace: string?,
}

local SUMMARY = "orion — keep a graph of work up to date from the command line"

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
	source = "List, add, or remove ingestion sources",
	ingest = "Import work from configured sources",
	matches = "List unplaced pull requests and likely cards",
	suggest = "Compute group suggestions",
	suggestions = "List, apply, or dismiss group suggestions",
	path = "Print where Orion keeps its data",
	backups = "List saved Orion data revisions",
	restore = "Restore a saved revision as a new revision",
	workspace = "List, create, and choose workspaces",
	help = "Show help for Orion or one of its commands",
}

local ABOUT = [[
Statuses: todo, active, review, blocked, deferred, done.
  Listed statuses are derived: todo shows as ready once nothing it waits on is open,
  and as blocked while something is. Notes pass blocking through and never count as work.
Repositories are "name" under the default owner (flipbook-labs) or "owner/name".
Data lives in ~/Library/Application Support/Orion/orion.json; set ORION_DATA_DIR to change it.
The Orion app watches that file, so changes show up while it's open.]]

local function addHelpFlag(parser: batteriesCli.Parser)
	parser:add("help", "flag", { help = "Show this help", aliases = { "h" } })
end

local function addJsonFlag(parser: batteriesCli.Parser)
	parser:add("json", "flag", { help = "Print JSON" })
end

local function addWorkspaceOption(parser: batteriesCli.Parser)
	parser:add("workspace", "option", { help = "Use this workspace for this command" })
end

local function addFieldOptions(parser: batteriesCli.Parser)
	parser:add("status", "option", { help = "todo, active, review, blocked, deferred, or done" })
	parser:add("repo", "option", { help = "Repository, as name or owner/name" })
	parser:add("pr", "option", { help = "Pull request number" })
	parser:add("who", "option", { help = "Whose move: you, review, or ci (empty to clear)" })
	parser:add("note", "option", { help = "Free-form note (empty to clear)" })
end

type Parsers = {
	root: batteriesCli.Parser,
	commands: { [string]: batteriesCli.Parser },
}

local function createParsers(): Parsers
	local root = batteriesCli.parser()
	addHelpFlag(root)
	addWorkspaceOption(root)
	local commands: { [string]: batteriesCli.Parser } = {}
	local function command(name: string): batteriesCli.Parser
		local parser = root:subcommand(name, { help = COMMAND_HELP[name] })
		addHelpFlag(parser)
		addWorkspaceOption(parser)
		commands[name] = parser
		return parser
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

	local add = command("add")
	add:add("label", "variadic", { help = "What the work is" })
	add:add("group", "option", { help = "Group to add it to" })
	addFieldOptions(add)
	addJsonFlag(add)

	local set = command("set")
	set:add("id", "positional", { help = "Item or group id" })
	set:add("label", "option", { help = "New label" })
	set:add("blurb", "option", { help = "Group description" })
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

	local ingestion = command("ingest")
	ingestion:add("dry-run", "flag", { help = "Show changes without writing" })
	ingestion:add("source", "option", { help = "Only ingest this source id" })
	addJsonFlag(ingestion)

	command("source")

	addJsonFlag(command("matches"))
	addJsonFlag(command("backups"))
	command("restore"):add("revision", "positional", { help = "Revision to restore" })

	local propose = command("suggest")
	propose:add("agent", "option", { help = "claude, codex, or none" })
	propose:add("scope", "option", { help = "unsorted or all" })
	propose:add("dry-run", "flag", { help = "Show suggestions without writing" })
	addJsonFlag(propose)

	local suggestions = command("suggestions")
	suggestions:add("action", "positional", { help = "apply or dismiss" })
	suggestions:add("ids", "variadic", { help = "Suggestion ids" })
	suggestions:add("all", "flag", { help = "Apply or dismiss every suggestion" })
	addJsonFlag(suggestions)

	command("path")
	local workspace = command("workspace")
	for _, name in { "list", "create", "use", "current" } do
		local sub = workspace:subcommand(name, { help = name })
		addHelpFlag(sub)
		addWorkspaceOption(sub)
		if name == "list" then
			addJsonFlag(sub)
		elseif name == "create" then
			sub:add("name", "positional", { help = "Workspace name" })
			sub:add("label", "option", { help = "Display label" })
			sub:add("owner", "option", { help = "Default GitHub owner" })
		elseif name == "use" then
			sub:add("name", "positional", { help = "Workspace name" })
		end
	end
	command("help"):add("command", "positional", { help = "Command to describe" })

	return { root = root, commands = commands }
end

local function rootHelp(parser: batteriesCli.Parser): string
	return table.concat({ SUMMARY, "", parser:usage("orion"), "", parser:help(), "", ABOUT }, "\n")
end

local function commandHelp(name: string, parser: batteriesCli.Parser): string
	return `{COMMAND_HELP[name]}\n\n{parser:usage(`orion {name}`)}\n\n{parser:help()}`
end

local function dependencies(options: Dependencies?): Resolved
	local given: Dependencies = options or {}
	return {
		runner = given.runner or defaultRun,
		write = given.write or print,
		dataDir = given.dataDir or store.defaultDir(),
		now = given.now or function()
			return os.date("!%Y-%m-%dT%H:%M:%SZ") :: string
		end,
		workspace = given.workspace or process.env.ORION_WORKSPACE,
	}
end

local function fields(parser: batteriesCli.Parser): graph.ItemFields
	local pr = parser:get("pr")
	local number = if pr then tonumber((pr:gsub("^#", ""))) else nil
	assert(pr == nil or number, "pr must be a number")
	return {
		label = if parser:has("label") then parser:get("label") else nil,
		blurb = parser:get("blurb"),
		status = parser:get("status"),
		repo = parser:get("repo"),
		pr = number,
		who = parser:get("who"),
		note = parser:get("note"),
	}
end

local function joined(values: { string }, what: string): string
	local text = table.concat(values, " ")
	assert(text ~= "", `missing {what}`)
	return text
end

local function required(parser: batteriesCli.Parser, name: string): string
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
		local la, lb = derived.leverage[a.id] or 0, derived.leverage[b.id] or 0
		if la ~= lb then
			return la > lb
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
		if not graph.isGroup(group) then
			continue
		end
		local total, done, ready = 0, 0, 0
		for _, item in doc.nodes do
			if item.type == "task" and not graph.isNote(item) and insideGroup(doc, item, group.id) then
				total += 1
				local status = derived.status[item.id]
				done += if status == "done" then 1 else 0
				ready += if status == "ready" then 1 else 0
			end
		end
		local object: json.Object =
			json.object({ id = group.id, label = graph.label(group), total = total, done = done, ready = ready })
		object.parent = group.parentId
		table.insert(values, object)
		table.insert(lines, `{group.id}  {graph.label(group)}  {done}/{total} done, {ready} ready`)
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
		table.insert(
			lines,
			`  added {id} to {if table.find(report.reviewAdded, id) then "Review requests" else "Inbox"}`
		)
	end
	if #report.missing > 0 then
		table.insert(lines, `  not found on GitHub: {table.concat(report.missing, ", ")}`)
	end
	return table.concat(lines, "\n")
end

local function sourceCommand(args: { string }, deps: Resolved, workspace: string?)
	local action = assert(args[2], "usage: orion source list|add|remove")
	local dir = store.workspaceDir(deps.dataDir, store.activeWorkspace(deps.dataDir, workspace, deps.workspace))
	if action == "list" then
		assert(#args == 2 or #args == 3 and args[3] == "--json", "usage: orion source list [--json]")
		local values = sources.asJson(store.load(dir).settings.sources)
		if args[3] == "--json" then
			deps.write(json.serialize(values, true))
		else
			local lines = {}
			for _, value in values do
				local source = json.asObject(value)
				if source then
					table.insert(lines, `{source.id}  {source.kind}`)
				end
			end
			deps.write(if #lines > 0 then table.concat(lines, "\n") else "No sources configured.")
		end
	elseif action == "add" then
		local source = sources.create({ table.unpack(args, 3) })
		store.transaction(dir, function(doc)
			for _, existing in doc.settings.sources do
				assert(existing.id ~= source.id, `source id "{source.id}" already exists`)
			end
			table.insert(doc.settings.sources, source)
		end)
		deps.write(`Added source {source.id}`)
	elseif action == "remove" then
		assert(#args == 3, "usage: orion source remove <id>")
		local id = args[3]
		store.transaction(dir, function(doc)
			local found = false
			for index = #doc.settings.sources, 1, -1 do
				if doc.settings.sources[index].id == id then
					table.remove(doc.settings.sources, index)
					found = true
				end
			end
			assert(found, `no source with id "{id}"`)
		end)
		deps.write(`Removed source {id}`)
	else
		error(`unknown source action {action}`)
	end
end

local function ingestReport(report: ingest.Report, dryRun: boolean): string
	local lines = { if dryRun then "Ingest dry run:" else "Ingested:" }
	for _, source in report.sources do
		table.insert(
			lines,
			`{source.id}: {source.added} added, {source.updated} updated, {source.linked} linked{if source.failed
				then `; failed: {source.failed}`
				else ""}`
		)
	end
	return table.concat(lines, "\n")
end

local function execute(args: { string }, options: Dependencies?)
	-- `source` parses its own arguments, so lift `--workspace` out of them first.
	local rest: { string } = {}
	local workspace: string? = nil
	local index = 1
	while index <= #args do
		if args[index] == "--workspace" then
			workspace = assert(args[index + 1], "--workspace needs a name")
			index += 2
		else
			table.insert(rest, args[index])
			index += 1
		end
	end
	if rest[1] == "source" and rest[2] ~= "--help" then
		sourceCommand(rest, dependencies(options), workspace)
		return
	end
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

	local root = deps.dataDir
	local selected = parser:get("workspace") or parsers.root:get("workspace")
	local workspaceCommand: string? = nil
	local workspaceParser: batteriesCli.Parser? = nil
	if command == "workspace" then
		workspaceCommand, workspaceParser = parser:selected()
	end
	if workspaceParser then
		selected = workspaceParser:get("workspace") or selected
	end
	if command == "workspace" then
		assert(workspaceCommand and workspaceParser, "choose list, create, use, or current")
		if workspaceCommand == "create" then
			local name = required(workspaceParser, "name")
			store.createWorkspace(root, name, workspaceParser:get("label"), workspaceParser:get("owner"))
			deps.write(`Created workspace {name}`)
		elseif workspaceCommand == "use" then
			local name = required(workspaceParser, "name")
			store.useWorkspace(root, name)
			deps.write(`Using workspace {name}`)
		elseif workspaceCommand == "list" then
			local list = store.workspaces(root)
			list.active = store.activeWorkspace(root, selected, deps.workspace)
			if workspaceParser:has("json") then
				local entries: json.Array = {}
				for _, entry in list.workspaces do
					table.insert(entries, json.object({ name = entry.name, label = entry.label }))
				end
				deps.write(json.serialize(json.object({ active = list.active, workspaces = entries }), true))
			else
				local lines = {}
				for _, entry in list.workspaces do
					table.insert(
						lines,
						`{if entry.name == list.active then "*" else " "} {entry.name} · {entry.label}`
					)
				end
				deps.write(table.concat(lines, "\n"))
			end
		elseif workspaceCommand == "current" then
			deps.write(store.activeWorkspace(root, selected, deps.workspace))
		end
		return
	end
	local active = store.activeWorkspace(root, selected, deps.workspace)
	local dir = store.workspaceDir(root, active)
	local asJson = parser:has("json")

	if command == "path" then
		deps.write(dir)
	elseif command == "backups" then
		local backups = store.backups(dir)
		if asJson then
			local values: json.Array = {}
			for _, backup in backups do
				table.insert(
					values,
					json.object({ revision = backup.revision, time = backup.time, size = backup.size })
				)
			end
			deps.write(json.serialize(values, true))
		else
			local lines: { string } = {}
			for _, backup in backups do
				table.insert(lines, `r{backup.revision}  {backup.time}  {backup.size} bytes`)
			end
			deps.write(if #lines > 0 then table.concat(lines, "\n") else "No backups.")
		end
	elseif command == "restore" then
		local value = required(parser, "revision")
		assert(value:match("^%d+$"), "revision must be a nonnegative integer")
		local revision = tonumber(value)
		local restored = store.transaction(dir, function(doc)
			local selected: store.Backup?
			for _, backup in store.backups(dir) do
				if backup.revision == revision then
					selected = backup
					break
				end
			end
			assert(selected, `no backup for revision {revision}`)
			local snapshot = store.decode(fs.readFileToString(selected.file))
			doc.nodes = snapshot.nodes
			doc.links = snapshot.links
			doc.settings = snapshot.settings
			doc.github = snapshot.github
			local raw = doc.raw or json.object({})
			raw.settings = if snapshot.raw then snapshot.raw.settings else nil
			doc.raw = raw
		end)
		deps.write(`Restored revision {revision} as revision {restored.revision}`)
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
	elseif command == "suggest" then
		local current = store.load(dir)
		local settings = if current.raw then json.asObject(current.raw.settings) else nil
		local configured = if settings and type(settings.agent) == "string" then settings.agent else nil
		local agent = parser:get("agent") or configured or "none"
		local result, fallback =
			suggest.compute(current, parser:get("scope") or "unsorted", agent, deps.runner, deps.now())
		if not parser:has("dry-run") then
			store.transaction(dir, function(doc)
				suggest.save(doc, result)
			end)
		end
		if asJson then
			local value = suggest.toJson(result)
			if fallback then
				value.warning = "Agent unavailable or returned no valid groups; kept heuristic suggestions."
			end
			deps.write(json.serialize(value, true))
		else
			local lines = { `{#result.groups} group suggestions{if parser:has("dry-run") then " (dry run)" else ""}:` }
			for _, group in result.groups do
				table.insert(
					lines,
					`  {group.id}  {group.title}  [{table.concat(group.members, ", ")}] — {group.reason}`
				)
			end
			if fallback then
				table.insert(lines, "Agent unavailable or returned no valid groups; kept heuristic suggestions.")
			end
			deps.write(table.concat(lines, "\n"))
		end
	elseif command == "suggestions" then
		local action = parser:get("action")
		if action == nil then
			local result = suggest.stored(store.load(dir))
			if asJson then
				deps.write(json.serialize(suggest.toJson(result), true))
			else
				local lines: { string } = {}
				for _, group in result.groups do
					table.insert(
						lines,
						`{group.id}  {group.title}  [{table.concat(group.members, ", ")}] — {group.reason}`
					)
				end
				deps.write(if #lines > 0 then table.concat(lines, "\n") else "No group suggestions.")
			end
		else
			assert(action == "apply" or action == "dismiss", "use suggestions apply or suggestions dismiss")
			local changed: { string } = {}
			store.transaction(dir, function(doc)
				changed = suggest.change(doc, action, parser:variadics(), parser:has("all"))
			end)
			deps.write(
				`{if action == "apply" then "Applied" else "Dismissed"} {#changed} suggestions: {table.concat(
					changed,
					", "
				)}`
			)
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
		local ids = {}
		for id in (parser:get("items") or ""):gmatch("[^,%s]+") do
			table.insert(ids, id)
		end
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
	elseif command == "ingest" then
		local dryRun = parser:has("dry-run")
		local now = deps.now()
		local fetched = ingest.collect(store.load(dir), deps.runner, now, parser:get("source"))
		local report: ingest.Report
		if dryRun then
			report = ingest.apply(store.load(dir), fetched, now)
		else
			store.transaction(dir, function(doc)
				report = ingest.apply(doc, fetched, now)
			end)
		end
		deps.write(if asJson then json.serialize(ingest.reportJson(report), true) else ingestReport(report, dryRun))
	end
end

-- Lute passes the program path as the first argument.
local function run(argv: { string })
	local ok, message = pcall(execute, { table.unpack(argv, 2) }, nil)
	if not ok then
		local text = tostring(message):gsub("^[^\n]-:%d+: ", "", 1)
		print(`Error: {text}`)
		process.exit(1)
	end
end

return table.freeze({
	execute = execute,
	run = run,
})
