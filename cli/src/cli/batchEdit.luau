local json = require("@std/json")

local applyOperations = require("@root/operations/applyOperations")
local graph = require("@root/graph")
local operationTypes = require("@root/operations/types")
local runEdit = require("@root/cli/runEdit")
local selectItems = require("@root/query/selectItems")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item

export type Options = {
	dir: string,
	action: string,
	ids: { string },
	where: string?,
	dryRun: boolean,
	asJson: boolean,
	ifRevision: number?,
	destination: string?,
	reconnect: boolean?,
	-- A line printed after the summary in text output.
	note: string?,
	-- Fields added to the JSON output.
	extra: json.Object?,
	write: (string) -> (),
}

-- `parent` marks something removed along with the group it sits in.
type Change = { id: string, label: string, parent: string? }

-- The operation one target gets. The app sends the same operations, so both paths edit the document one way.
local function editFor(options: Options, id: string): operationTypes.Operation
	if options.action == "done" then
		return { op = "setFields", id = id, fields = { status = "done" } }
	elseif options.action == "remove" then
		return { op = "remove", id = id, reconnect = options.reconnect }
	elseif options.action == "ungroup" then
		return { op = "ungroup", id = id }
	elseif options.action == "removeGroup" then
		return { op = "removeGroup", id = id }
	elseif options.action == "tidy" then
		return { op = "tidy", id = id }
	end

	return { op = "move", id = id, group = options.destination }
end

local function batchEdit(options: Options)
	assert(#options.ids == 0 or options.where == nil, "use ids or --where, not both")
	assert(#options.ids > 0 or options.where ~= nil, "provide ids or --where")

	local changes: { Change } = {}

	local function apply(doc: Doc)
		local targets: { Item } = {}
		if options.where then
			targets = selectItems(doc, options.where, true)
		else
			local seen: { [string]: boolean } = {}
			for _, id in options.ids do
				assert(not seen[id], `duplicate id: {id}`)
				seen[id] = true
				local item = graph.get(doc, id)
				table.insert(targets, item)
			end
		end

		for _, item in targets do
			if options.action == "done" then
				assert(item.type == "task", `"{item.id}" is not a work item`)
			elseif options.action == "remove" then
				assert(not graph.isGroup(item), `"{item.id}" is a group; use group ungroup or group remove instead`)
			elseif options.action == "ungroup" or options.action == "tidy" or options.action == "removeGroup" then
				assert(graph.isGroup(item), `"{item.id}" is an item, not a group`)
			end
			table.insert(changes, { id = item.id, label = graph.label(item) })

			if options.action == "removeGroup" then
				for _, inside in graph.contents(doc, item.id) do
					table.insert(changes, { id = inside.id, label = graph.label(inside), parent = item.id })
				end
			end
		end

		assert(#targets > 0, "no items match")
		if options.action == "remove" and options.reconnect then
			for _, item in targets do
				graph.checkReconnect(doc, item.id)
			end
		end

		-- A group inside another target group leaves with it, so it isn't removed twice.
		local targetedGroups: { [string]: boolean } = {}

		if options.action == "removeGroup" then
			for _, item in targets do
				targetedGroups[item.id] = true
			end
		end

		local edits: { operationTypes.Operation } = {}

		for _, item in targets do
			local insideTarget = false

			for _, ancestor in graph.ancestors(doc, item.id) do
				insideTarget = insideTarget or targetedGroups[ancestor] == true
			end

			if not insideTarget then
				table.insert(edits, editFor(options, item.id))
			end
		end

		applyOperations(doc, edits)
	end

	local result, baseRevision = runEdit(options.dir, options.dryRun, options.ifRevision, apply)

	if options.asJson then
		local entries: json.Array = {}
		for _, change in changes do
			table.insert(entries, json.object({ id = change.id, label = change.label, within = change.parent }))
		end
		local report = json.object({
			action = options.action,
			dryRun = options.dryRun,
			baseRevision = baseRevision,
			revision = result.revision,
			items = entries,
			destination = if options.action == "move" then options.destination or json.null else nil,
		})

		for key, value in options.extra or {} do
			report[key] = value
		end

		options.write(json.serialize(report, true))
		return
	end

	local count = #changes
	local inside = 0

	for _, change in changes do
		if change.parent then
			inside += 1
		end
	end

	count -= inside
	local noun = if options.action == "ungroup"
			or options.action == "tidy"
			or options.action == "removeGroup"
		then (if count == 1 then "group" else "groups")
		else (if count == 1 then "item" else "items")
	local summary: string
	if options.action == "done" then
		summary = if options.dryRun then `Would mark {count} {noun} done` else `Marked {count} {noun} done`
	elseif options.action == "remove" then
		summary = if options.dryRun then `Would remove {count} {noun}` else `Removed {count} {noun}`
	elseif options.action == "ungroup" then
		summary = if options.dryRun then `Would ungroup {count} {noun}` else `Ungrouped {count} {noun}`
	elseif options.action == "removeGroup" then
		local contents = `{inside} {if inside == 1 then "thing" else "things"} inside`
		summary = if options.dryRun
			then `Would remove {count} {noun} and {contents}`
			else `Removed {count} {noun} and {contents}`
	elseif options.action == "tidy" then
		summary = if options.dryRun then `Would tidy {count} {noun}` else `Marked {count} {noun} to tidy`
	else
		local destination = options.destination or "the top level"
		summary = if options.dryRun
			then `Would move {count} {noun} to {destination}`
			else `Moved {count} {noun} to {destination}`
	end
	local revision = if options.dryRun then `{baseRevision}` else `{baseRevision} → {result.revision}`
	local lines = { `{summary} at revision {revision}` }
	for _, change in changes do
		table.insert(lines, `{if change.parent then "    " else "  "}{change.id} · {change.label}`)
	end
	if options.note then
		table.insert(lines, options.note)
	end
	options.write(table.concat(lines, "\n"))
end

return batchEdit
