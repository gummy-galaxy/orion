local json = require("@std/json")

local graph = require("@root/graph")
local refs = require("@root/refs")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item

local render = {}

local function str(value: json.Value): string?
	return if type(value) == "string" then value else nil
end

function render.tag(item: Item): string
	if graph.isNote(item) then
		return "note"
	end
	return refs.itemTag(item) or str(item.data.itemKind) or "step"
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
	local driver = refs.driver(item)
	object.repo = if driver then driver.repo else refs.repo(item)
	object.pr = if driver then driver.number else nil
	object.who = item.data.who
	object.note = item.data.note
	object.github = if driver then driver.state else nil
	local sources: json.Array = {}
	for _, ref in refs.ordered(item) do
		local copy = json.object(ref)
		copy.href = refs.url(ref, doc.settings.githubOwner)
		table.insert(sources, copy)
	end
	if #sources > 0 then
		object.sources = sources
	end
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
	if graph.isGroup(item) then
		object.arrange = str(item.data.arrange) or "auto"
		object.columns = item.data.columns
	end
	return object
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
		local arrange = str(item.data.arrange)
		if arrange then
			local columns = item.data.columns
			table.insert(lines, `  arrange  {arrange}{if type(columns) == "number" then `, {columns} columns` else ""}`)
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
	for _, ref in refs.ordered(item) do
		local href = refs.url(ref, doc.settings.githubOwner)
		table.insert(lines, `  source   {refs.describe(ref)}{if href then `  {href}` else ""}`)
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

return table.freeze(render)
