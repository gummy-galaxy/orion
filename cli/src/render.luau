local json = require("@std/json")

local graph = require("@root/graph")
local types = require("@root/types")

type Doc = types.Doc
type Focus = types.Focus
type Item = types.Item

local render = {}

local function str(value: json.Value): string?
	return if type(value) == "string" then value else nil
end

function render.tag(item: Item): string
	local repo = str(item.data.repo)
	local pr = item.data.pr
	if graph.isNote(item) then
		return "note"
	elseif repo and type(pr) == "number" then
		return `{repo}#{pr}`
	end
	return repo or "step"
end

local function groupLabel(doc: Doc, item: Item): string?
	local parent = if item.parentId then graph.find(doc, item.parentId) else nil
	return if parent then graph.label(parent) else nil
end

function render.itemJson(doc: Doc, derived: graph.Derived, item: Item): json.Object
	local object: json.Object = json.object({
		id = item.id,
		label = graph.label(item),
		kind = str(item.data.itemKind) or "step",
		status = derived.status[item.id] or "ready",
		recordedStatus = str(item.data.status) or "todo",
		unblocks = derived.leverage[item.id] or 0,
	})
	object.group = item.parentId
	object.groupLabel = groupLabel(doc, item)
	object.repo = item.data.repo
	object.pr = item.data.pr
	object.who = item.data.who
	object.note = item.data.note
	object.github = item.data.github
	local waitsOn: json.Array = {}
	local unblocks: json.Array = {}
	for _, link in doc.links do
		if link.kind == "blocks" and link.to == item.id then
			table.insert(waitsOn, link.from)
		elseif link.kind == "blocks" and link.from == item.id then
			table.insert(unblocks, link.to)
		end
	end
	object.waitsOn = waitsOn
	object.leadsTo = unblocks
	return object
end

function render.serializeGroup(doc: Doc, derived: graph.Derived, group: Item): json.Object
	local progress = graph.countProgress(doc, derived, group.id)
	local object: json.Object = json.object({
		id = group.id,
		label = graph.label(group),
		total = progress.total,
		done = progress.done,
		ready = progress.ready,
	})
	object.parent = group.parentId
	return object
end

function render.formatGroupLine(doc: Doc, derived: graph.Derived, group: Item): string
	local progress = graph.countProgress(doc, derived, group.id)
	return `{graph.label(group)}  {progress.done}/{progress.total} done, {progress.ready} ready`
end

local function pad(text: string, width: number): string
	if #text >= width then
		return text:sub(1, width - 1) .. "…"
	end
	return text .. string.rep(" ", width - #text)
end

function render.table(doc: Doc, derived: graph.Derived, items: { Item }): string
	if #items == 0 then
		return "Nothing matches."
	end
	local lines = {}
	for _, item in items do
		local status = derived.status[item.id] or "ready"
		local leverage = derived.leverage[item.id] or 0
		local extra = if leverage > 0 and status ~= "done" then `  unblocks {leverage}` else ""
		local where = groupLabel(doc, item)
		table.insert(
			lines,
			`{pad(status, 9)}{pad(item.id, 24)}{pad(graph.label(item), 44)}{pad(render.tag(item), 20)}{where or ""}{extra}`
		)
	end
	return table.concat(lines, "\n")
end

function render.show(doc: Doc, derived: graph.Derived, item: Item): string
	if graph.isGroup(item) then
		local lines = { `{graph.label(item)}  ({item.id}, group)` }
		local blurb = str(item.data.blurb)
		if blurb then
			table.insert(lines, blurb)
		end
		for _, child in doc.nodes do
			if child.parentId == item.id then
				table.insert(lines, `  {pad(derived.status[child.id] or "group", 9)}{child.id}  {graph.label(child)}`)
			end
		end
		return table.concat(lines, "\n")
	end
	local lines = {
		`{graph.label(item)}`,
		`  id       {item.id}`,
		`  kind     {render.tag(item)}`,
		`  status   {derived.status[item.id] or "ready"} (recorded {str(item.data.status) or "todo"})`,
	}
	local where = groupLabel(doc, item)
	if where then
		table.insert(lines, `  group    {where} ({item.parentId})`)
	end
	local who = str(item.data.who)
	if who then
		table.insert(lines, `  move     {who}`)
	end
	local leverage = derived.leverage[item.id] or 0
	if leverage > 0 then
		table.insert(lines, `  unblocks {leverage}`)
	end
	for _, link in doc.links do
		local other = if link.to == item.id then link.from elseif link.from == item.id then link.to else nil
		if other then
			local direction = if link.kind ~= "blocks"
				then "related"
				elseif link.to == item.id then "waits on"
				else "leads to"
			local target = graph.find(doc, other)
			table.insert(lines, `  {pad(direction, 9)}{other}  {if target then graph.label(target) else ""}`)
		end
	end
	local note = str(item.data.note)
	if note then
		table.insert(lines, `  note     {note}`)
	end
	return table.concat(lines, "\n")
end

-- Ids the app reported that are still on the canvas; the app can be a moment behind the file.
local function findSelectedItems(doc: Doc, focus: Focus): { Item }
	local items = {}
	for _, id in focus.selected do
		local item = graph.find(doc, id)
		if item then
			table.insert(items, item)
		end
	end
	return items
end

local function findOpenGroup(doc: Doc, focus: Focus): Item?
	local item = if focus.open then graph.find(doc, focus.open) else nil
	return if item and graph.isGroup(item) then item else nil
end

-- The open group's ancestors, outermost first.
local function findAncestorTrail(doc: Doc, group: Item): { Item }
	local out = {}
	for _, id in graph.ancestors(doc, group.id) do
		local parent = graph.find(doc, id)
		if parent then
			table.insert(out, 1, parent)
		end
	end
	return out
end

function render.serializeFocus(doc: Doc, derived: graph.Derived, focus: Focus?): json.Object
	local object: json.Object = json.object({ appOpen = focus ~= nil })
	local selected: json.Array = {}
	object.selected = selected
	if not focus then
		return object
	end
	object.updatedAt = focus.updatedAt
	local group = findOpenGroup(doc, focus)
	if group then
		local open = render.serializeGroup(doc, derived, group)
		local path: json.Array = {}
		for _, parent in findAncestorTrail(doc, group) do
			table.insert(path, json.object({ id = parent.id, label = graph.label(parent) }))
		end
		open.path = path
		object.open = open
	end
	for _, item in findSelectedItems(doc, focus) do
		if graph.isGroup(item) then
			local entry = render.serializeGroup(doc, derived, item)
			entry.kind = "group"
			table.insert(selected, entry)
		else
			table.insert(selected, render.itemJson(doc, derived, item))
		end
	end
	return object
end

function render.formatFocus(doc: Doc, derived: graph.Derived, focus: Focus?): string
	if not focus then
		return "The Orion app isn't open, so nothing is in focus."
	end
	local lines = {}
	local group = findOpenGroup(doc, focus)
	if group then
		local within = {}
		for _, parent in findAncestorTrail(doc, group) do
			table.insert(within, graph.label(parent))
		end
		local inside = if #within > 0 then `, inside {table.concat(within, " › ")}` else ""
		table.insert(lines, `Open: {group.id}  {render.formatGroupLine(doc, derived, group)}{inside}`)
	else
		table.insert(lines, "Open: the top level")
	end
	local items = findSelectedItems(doc, focus)
	if #items == 0 then
		table.insert(lines, "Nothing selected.")
	else
		table.insert(lines, "Selected:")
		for _, item in items do
			if graph.isGroup(item) then
				table.insert(lines, `  {pad("group", 9)}{pad(item.id, 24)}{render.formatGroupLine(doc, derived, item)}`)
			else
				table.insert(lines, `  {render.table(doc, derived, { item })}`)
			end
		end
	end
	if focus.updatedAt then
		table.insert(lines, `As of {focus.updatedAt}`)
	end
	return table.concat(lines, "\n")
end

return table.freeze(render)
