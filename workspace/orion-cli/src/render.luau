local json = require("@std/json")

local findItem = require("@root/graph/findItem")
local getItemTypes = require("@root/cardTypes/getItemTypes")
local getLabel = require("@root/graph/getLabel")
local getPrimaryRef = require("@root/refs/getPrimaryRef")
local graphTypes = require("@root/graph/types")
local isComponent = require("@root/graph/isComponent")
local isGate = require("@root/graph/isGate")
local isGroup = require("@root/graph/isGroup")
local isNote = require("@root/graph/isNote")
local pad = require("@root/render/pad")
local renderGroup = require("@root/render/group")
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
	elseif isNote(item) then
		return "note"
	elseif isComponent(item) then
		return "component"
	elseif isGate(item) then
		return "gate"
	end

	return "step"
end

local function groupLabel(doc: Doc, item: Item): string?
	local parent = if item.parentId then findItem(doc, item.parentId) else nil
	return if parent then getLabel(parent) else nil
end

function render.itemJson(doc: Doc, derived: graphTypes.Derived, item: Item): json.Object
	if isGroup(item) then
		return renderGroup.serialize(derived, item)
	end

	if item.type == "image" then
		local image = json.object({
			id = item.id,
			kind = "image",
			asset = item.data.asset,
			canvas = item.data.canvas,
		})
		image.label = asString(item.data.label)
		image.group = item.parentId
		return image
	end

	local object: json.Object = json.object({
		id = item.id,
		kind = asString(item.data.itemKind) or "step",
		types = (assert(getItemTypes(item))).types :: any,
	})
	object.label = asString(item.data.label)

	-- Notes pass blocking through and components draw a system, so neither
	-- carries a status.
	if not isNote(item) then
		object.unblocks = derived.leverage[item.id] or 0
	end

	if not (isComponent(item) or isNote(item)) then
		object.status = derived.status[item.id] or "ready"
		object.recordedStatus = asString(item.data.status) or "todo"
		object.snoozedUntil = derived.snoozed[item.id] or nil
	end

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

	return object
end

function render.table(doc: Doc, derived: graphTypes.Derived, items: { Item }): string
	if #items == 0 then
		return "Nothing matches."
	end

	local lines = {}

	for _, item in items do
		local status = if isComponent(item) then "-" else derived.status[item.id] or "ready"
		local leverage = derived.leverage[item.id] or 0
		local extra = if leverage > 0 and status ~= "done" then `  unblocks {leverage}` else ""
		local where = groupLabel(doc, item)
		table.insert(
			lines,
			`{pad(status, 9)}{pad(item.id, 38)}{pad(getLabel(item), 44)}{pad(render.tag(item), 20)}{where or ""}{extra}`
		)
	end

	return table.concat(lines, "\n")
end

-- Children without a status, such as components and images, show what they are
-- instead.
local function kindOf(child: Item): string
	return if isComponent(child) then "component" else child.type
end

function render.show(doc: Doc, derived: graphTypes.Derived, item: Item): string
	if isGroup(item) then
		local lines = { `{getLabel(item)}  ({item.id}, group)` }
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
					`  {pad(derived.status[child.id] or kindOf(child), 10)}{child.id}  {getLabel(child)}`
				)
			end
		end

		return table.concat(lines, "\n")
	end
	if item.type == "image" then
		local lines = {
			getLabel(item),
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
		`{getLabel(item)}`,
		`  id       {item.id}`,
		`  kind     {render.tag(item)}`,
	}

	if isComponent(item) then
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
			local isItemComponent = isComponent(item)
			local direction = if link.kind ~= "blocks"
				then "related"
				elseif link.to == item.id then (if isItemComponent then "from" else "waits on")
				else (if isItemComponent then "to" else "leads to")
			local target = findItem(doc, other)
			local label = if link.label then `  "{link.label}"` else ""
			table.insert(lines, `  {pad(direction, 9)}{other}  {if target then getLabel(target) else ""}{label}`)
		end
	end

	local note = asString(item.data.note)

	if note then
		table.insert(lines, `  note     {note}`)
	end

	return table.concat(lines, "\n")
end

return table.freeze(render)
