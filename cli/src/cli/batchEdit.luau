local json = require("@std/json")

local graph = require("@root/graph")
local resolveId = require("@root/query/resolveId")
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

local function batchEdit(options: Options)
	assert(#options.ids == 0 or options.where == nil, "use ids or --where, not both")
	assert(#options.ids > 0 or options.where ~= nil, "provide ids or --where")

	local changes: { Change } = {}
	local destination = options.destination

	local function apply(doc: Doc)
		local targets: { Item } = {}
		if options.where then
			targets = selectItems(doc, options.where, true)
		else
			local seen: { [string]: boolean } = {}
			for _, input in options.ids do
				local id = resolveId(doc, input)
				assert(not seen[id], `duplicate id: {id}`)
				seen[id] = true
				local item = graph.get(doc, id)
				table.insert(targets, item)
			end
		end

		if options.destination then
			destination = resolveId(doc, options.destination)
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

		for _, item in targets do
			if options.action == "done" then
				graph.setFields(doc, item.id, { status = "done" })
			elseif options.action == "remove" then
				graph.remove(doc, item.id, options.reconnect)
			elseif options.action == "ungroup" then
				graph.ungroup(doc, item.id)
			elseif options.action == "removeGroup" then
				if graph.find(doc, item.id) then
					graph.removeGroup(doc, item.id)
				end
			elseif options.action == "tidy" then
				graph.markForTidy(doc, item.id)
			else
				graph.move(doc, item.id, destination)
			end
		end
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
			destination = if options.action == "move" then destination or json.null else nil,
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
		local target = destination or "the top level"
		summary = if options.dryRun then `Would move {count} {noun} to {target}` else `Moved {count} {noun} to {target}`
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
