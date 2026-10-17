local json = require("@std/json")

local getPrimaryRef = require("@root/refs/getPrimaryRef")
local graph = require("@root/graph")
local pad = require("@root/render/pad")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item

local render = {}

local function asString(value: json.Value): string?
	return if type(value) == "string" then value else nil
end

function render.tag(item: Item): string
	local repo = asString(item.data.repo)
	local primary = getPrimaryRef(item)

	if primary then
		return primary.key
	elseif repo then
		return repo
	elseif graph.isNote(item) then
		return "note"
	elseif graph.isComponent(item) then
		return "component"
	elseif graph.isGate(item) then
		return "gate"
	end

	return "step"
end

local function groupLabel(doc: Doc, item: Item): string?
	local parent = if item.parentId then graph.find(doc, item.parentId) else nil
	return if parent then graph.label(parent) else nil
end

function render.itemJson(doc: Doc, derived: graph.Derived, item: Item): json.Object
	if item.type == "image" then
		return json.object({
			id = item.id,
			label = graph.label(item),
			kind = "image",
			asset = item.data.asset,
			workspace = item.data.workspace,
			group = item.parentId,
		})
	end
	local object: json.Object = json.object({
		id = item.id,
		label = graph.label(item),
		kind = asString(item.data.itemKind) or "step",
		unblocks = derived.leverage[item.id] or 0,
	})

	if not graph.isComponent(item) then
		object.status = derived.status[item.id] or "ready"
		object.recordedStatus = asString(item.data.status) or "todo"
	end

	object.snoozedUntil = derived.snoozed[item.id] or nil
	object.group = item.parentId
	object.groupLabel = groupLabel(doc, item)
	object.repo = item.data.repo
	object.refs = item.data.refs
	object.who = item.data.who
	object.note = item.data.note
	object.shape = item.data.shape
	object.color = item.data.color
	local waitsOn: json.Array = {}
	local unblocks: json.Array = {}
	local labels: json.Array = {}

	for _, link in doc.links do
		if link.kind == "blocks" and link.to == item.id then
			table.insert(waitsOn, link.from)
		elseif link.kind == "blocks" and link.from == item.id then
			table.insert(unblocks, link.to)
		end

		if link.label and (link.from == item.id or link.to == item.id) then
			table.insert(labels, json.object({ from = link.from, to = link.to, label = link.label }))
		end
	end

	object.waitsOn = waitsOn
	object.leadsTo = unblocks

	if #labels > 0 then
		object.linkLabels = labels
	end

	if graph.isGroup(item) then
		object.arrange = asString(item.data.arrange) or "auto"
	end
	return object
end

function render.table(doc: Doc, derived: graph.Derived, items: { Item }): string
	if #items == 0 then
		return "Nothing matches."
	end

	local lines = {}

	for _, item in items do
		local status = if graph.isComponent(item) then "-" else derived.status[item.id] or "ready"
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

-- Children without a status, such as components and images, show what they are instead.
local function kindOf(child: Item): string
	return if graph.isComponent(child) then "component" else child.type
end

function render.show(doc: Doc, derived: graph.Derived, item: Item): string
	if graph.isGroup(item) then
		local lines = { `{graph.label(item)}  ({item.id}, group)` }
		local blurb = asString(item.data.blurb)

		if blurb then
			table.insert(lines, blurb)
		end

		local arrange = asString(item.data.arrange)
		if arrange then
			table.insert(lines, `  arrange  {arrange}`)
		end

		local color = asString(item.data.color)
		if color then
			table.insert(lines, `  color    {color}`)
		end

		for _, child in doc.nodes do
			if child.parentId == item.id then
				table.insert(
					lines,
					`  {pad(derived.status[child.id] or kindOf(child), 10)}{child.id}  {graph.label(child)}`
				)
			end
		end

		return table.concat(lines, "\n")
	end
	if item.type == "image" then
		local lines = {
			graph.label(item),
			`  id       {item.id}`,
			"  kind     image",
			`  asset    {asString(item.data.asset) or ""}`,
		}
		local where = groupLabel(doc, item)
		if where then
			table.insert(lines, `  group    {where} ({item.parentId})`)
		end
		return table.concat(lines, "\n")
	end
	local lines = {
		`{graph.label(item)}`,
		`  id       {item.id}`,
		`  kind     {render.tag(item)}`,
	}

	if graph.isComponent(item) then
		table.insert(lines, `  shape    {asString(item.data.shape) or "service"}`)

		local color = asString(item.data.color)
		if color then
			table.insert(lines, `  color    {color}`)
		end
	else
		local status = derived.status[item.id] or "ready"
		table.insert(lines, `  status   {status} (recorded {asString(item.data.status) or "todo"})`)
	end

	local where = groupLabel(doc, item)

	if where then
		table.insert(lines, `  group    {where} ({item.parentId})`)
	end

	local who = asString(item.data.who)

	if who then
		table.insert(lines, `  move     {who}`)
	end

	local wakesAt = derived.snoozed[item.id]

	if wakesAt then
		table.insert(lines, `  snoozed  until {wakesAt}`)
	end

	local leverage = derived.leverage[item.id] or 0

	if leverage > 0 then
		table.insert(lines, `  unblocks {leverage}`)
	end

	for _, link in doc.links do
		local other = if link.to == item.id then link.from elseif link.from == item.id then link.to else nil

		if other then
			local isComponent = graph.isComponent(item)
			local direction = if link.kind ~= "blocks"
				then "related"
				elseif link.to == item.id then (if isComponent then "from" else "waits on")
				else (if isComponent then "to" else "leads to")
			local target = graph.find(doc, other)
			local label = if link.label then `  "{link.label}"` else ""
			table.insert(lines, `  {pad(direction, 9)}{other}  {if target then graph.label(target) else ""}{label}`)
		end
	end

	local note = asString(item.data.note)

	if note then
		table.insert(lines, `  note     {note}`)
	end

	return table.concat(lines, "\n")
end

return table.freeze(render)
