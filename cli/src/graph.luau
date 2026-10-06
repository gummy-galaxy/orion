local json = require("@std/json")

local refs = require("@root/refs")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item
type Link = types.Link
type Position = types.Position

-- Card and group sizes match the app so CLI placements line up with its layout.
local TASK_W = 216
local TASK_H = 72
local PAD = 32
local HEAD = 78
local GAP = 48

local STATUSES = { todo = true, active = true, review = true, blocked = true, deferred = true, done = true }
local WHO = { you = true, review = true, ci = true }
local ARRANGE = { auto = true, grid = true, custom = true }

export type Derived = {
	status: { [string]: string },
	leverage: { [string]: number },
}

export type ItemFields = {
	label: string?,
	status: string?,
	repo: string?,
	pr: number?,
	who: string?,
	note: string?,
	blurb: string?,
	kind: string?,
	arrange: string?,
	columns: number?,
}

local graph = {}

local function field(item: Item, key: string): string?
	local value = item.data[key]
	return if type(value) == "string" then value else nil
end

function graph.label(item: Item): string
	return field(item, "label") or ""
end

function graph.isGroup(item: Item): boolean
	return item.type == "cluster"
end

function graph.isNote(item: Item): boolean
	return item.type == "task" and field(item, "itemKind") == "note"
end

function graph.isGate(item: Item): boolean
	return item.type == "task" and field(item, "itemKind") == "gate"
end

function graph.find(doc: Doc, id: string): Item?
	for _, item in doc.nodes do
		if item.id == id then
			return item
		end
	end
	return nil
end

function graph.get(doc: Doc, id: string): Item
	return assert(graph.find(doc, id), `no item or group with id "{id}"`)
end

function graph.group(doc: Doc, id: string): Item
	local item = graph.get(doc, id)
	assert(graph.isGroup(item), `"{id}" is an item, not a group`)
	return item
end

function graph.ancestors(doc: Doc, id: string): { string }
	local out = {}
	local current = graph.find(doc, id)
	while current and current.parentId do
		table.insert(out, current.parentId)
		current = graph.find(doc, current.parentId)
	end
	return out
end

local function sizeOf(item: Item): (number, number)
	if item.type == "task" then
		return TASK_W, TASK_H
	end
	return item.width or 320, item.height or 200
end

-- Status and leverage, matching app/src/derive.ts. Notes pass blocking through and never count as work. Gates
-- also pass blocking through, but count as work: one is done once everything it waits on is.
function graph.derive(doc: Doc): Derived
	local tasks: { [string]: Item } = {}
	for _, item in doc.nodes do
		if item.type == "task" then
			tasks[item.id] = item
		end
	end
	local preds: { [string]: { string } } = {}
	local succs: { [string]: { string } } = {}
	for _, link in doc.links do
		if link.kind == "blocks" then
			preds[link.to] = preds[link.to] or {}
			succs[link.from] = succs[link.from] or {}
			table.insert(preds[link.to], link.from)
			table.insert(succs[link.from], link.to)
		end
	end

	local noteOpen: { [string]: boolean } = {}
	local function isOpen(id: string, seen: { [string]: boolean }?): boolean
		local item = tasks[id]
		if not item then
			return false
		end
		local passes = graph.isNote(item) or (graph.isGate(item) and preds[id] ~= nil)
		if not passes then
			return field(item, "status") ~= "done"
		end
		if noteOpen[id] ~= nil then
			return noteOpen[id]
		end
		local visited = seen or {}
		if visited[id] then
			return false
		end
		visited[id] = true
		local result = false
		for _, p in preds[id] or {} do
			if isOpen(p, visited) then
				result = true
				break
			end
		end
		noteOpen[id] = result
		return result
	end

	local status: { [string]: string } = {}
	for id, item in tasks do
		local recorded = field(item, "status") or "todo"
		local blockedByDeps = false
		for _, p in preds[id] or {} do
			if isOpen(p) then
				blockedByDeps = true
				break
			end
		end
		if graph.isNote(item) or (graph.isGate(item) and preds[id] and recorded ~= "deferred") then
			status[id] = if isOpen(id) then "blocked" else "done"
		elseif recorded == "done" or recorded == "deferred" or recorded == "blocked" then
			status[id] = recorded
		elseif blockedByDeps then
			status[id] = "blocked"
		else
			status[id] = if recorded == "todo" then "ready" else recorded
		end
	end

	local leverage: { [string]: number } = {}
	for id, item in tasks do
		if graph.isNote(item) or not isOpen(id) then
			continue
		end
		local seen: { [string]: boolean } = {}
		local stack = { id }
		local count = 0
		while #stack > 0 do
			local current = table.remove(stack) :: string
			for _, next in succs[current] or {} do
				local nextItem = tasks[next]
				if seen[next] or not nextItem or not isOpen(next) or field(nextItem, "status") == "deferred" then
					continue
				end
				seen[next] = true
				if not graph.isNote(nextItem) then
					count += 1
				end
				table.insert(stack, next)
			end
		end
		leverage[id] = count
	end

	return { status = status, leverage = leverage }
end

local function slug(text: string): string
	local value = text:lower():gsub("[^%w]+", "-"):gsub("^%-+", ""):gsub("%-+$", "")
	value = value:sub(1, 32):gsub("%-+$", "")
	return if value == "" then "item" else value
end

local function uniqueId(doc: Doc, base: string): string
	if not graph.find(doc, base) then
		return base
	end
	local n = 2
	while graph.find(doc, `{base}-{n}`) do
		n += 1
	end
	return `{base}-{n}`
end

-- The next free spot to the right of a parent's children, or of the top level.
function graph.nextSlot(doc: Doc, parentId: string?): Position
	local right: number? = nil
	local top: number? = nil
	for _, item in doc.nodes do
		if item.parentId == parentId then
			local w = sizeOf(item)
			right = math.max(right or -math.huge, item.position.x + w)
			top = math.min(top or math.huge, item.position.y)
		end
	end
	if right == nil or top == nil then
		return if parentId then { x = PAD, y = HEAD } else { x = 0, y = 0 }
	end
	return { x = (right :: number) + (if parentId then GAP else GAP * 2), y = top :: number }
end

local function checkFields(fields: ItemFields)
	assert(
		fields.status == nil or STATUSES[fields.status],
		`status must be one of todo, active, review, blocked, deferred, done`
	)
	assert(fields.who == nil or fields.who == "" or WHO[fields.who], `who must be one of you, review, ci`)
	assert(fields.pr == nil or (fields.pr > 0 and fields.pr % 1 == 0), "pr must be a positive whole number")
	assert(fields.kind == nil or fields.kind == "step" or fields.kind == "gate", "kind must be step or gate")
	assert(fields.arrange == nil or ARRANGE[fields.arrange], "arrange must be one of auto, grid, custom")
	assert(
		fields.columns == nil or (fields.columns > 0 and fields.columns % 1 == 0),
		"columns must be a positive whole number"
	)
end

export type AddOptions = ItemFields & { group: string?, sources: { refs.Ref }? }

function graph.addItem(doc: Doc, label: string, options: AddOptions): Item
	assert(label ~= "", "an item needs a label")
	checkFields(options)
	if options.group then
		graph.group(doc, options.group)
	end
	local first = if options.sources then options.sources[1] else nil
	local base = if options.repo and options.pr
		then `{slug(options.repo)}-{options.pr}`
		elseif first and type(first.number) == "number" then `{slug((refs.tag(first):gsub("#.*$", "")))}-{first.number}`
		else slug(label)
	local data: json.Object = json.object({
		kind = "task",
		label = label,
		itemKind = if options.kind == "gate" then "gate" else "step",
		status = options.status or "todo",
	})
	data.note = options.note
	data.who = if options.who == "" then nil else options.who
	local item: Item = {
		id = uniqueId(doc, base),
		type = "task",
		position = graph.nextSlot(doc, options.group),
		parentId = options.group,
		data = data,
	}
	if options.repo or options.pr then
		refs.setPull(item, options.repo, options.pr)
	end
	for _, ref in options.sources or {} do
		graph.linkJira(doc, ref)
		refs.attach(item, ref)
	end
	data.itemKind = refs.itemKind(item)
	table.insert(doc.nodes, item)
	return item
end

function graph.addImage(doc: Doc, label: string, extension: string, workspace: string, group: string?): Item
	assert(label ~= "", "an image needs a label")
	if group then
		graph.group(doc, group)
	end
	local id = uniqueId(doc, `image-{slug(label)}`)
	local item: Item = {
		id = id,
		type = "image",
		position = graph.nextSlot(doc, group),
		parentId = group,
		width = 256,
		height = 256,
		data = json.object({ kind = "image", label = label, asset = `{id}.{extension}`, workspace = workspace }),
	}
	table.insert(doc.nodes, item)
	return item
end

--- Where this canvas's Jira tickets open: the Jira source's browse URL, or the site of a ticket already linked.
local function jiraBrowse(doc: Doc): string?
	for _, source in doc.settings.sources do
		if source.kind == "jira" and source.browse then
			return source.browse
		end
	end
	for _, item in doc.nodes do
		if item.type == "task" then
			for _, ref in refs.ofKind(item, "jira") do
				local url = if type(ref.url) == "string" then ref.url else nil
				local browse = url and url:match("^(https://[^/@]+.-/browse)/[^/]+$")
				if browse then
					return browse
				end
			end
		end
	end
	return nil
end

--- Gives a bare Jira key the link its siblings have, so every ticket opens.
function graph.linkJira(doc: Doc, ref: refs.Ref)
	if ref.kind == "jira" and not ref.url and type(ref.key) == "string" then
		local browse = jiraBrowse(doc)
		if browse then
			ref.url = `{browse}/{ref.key}`
		end
	end
end

function graph.attach(doc: Doc, id: string, ref: refs.Ref): Item
	local item = graph.get(doc, id)
	assert(not graph.isGroup(item), `"{id}" is a group; attach sources to the items inside it`)
	graph.linkJira(doc, ref)
	refs.attach(item, ref)
	return item
end

function graph.detach(doc: Doc, id: string, ref: refs.Ref): Item
	local item = graph.get(doc, id)
	assert(not graph.isGroup(item), `"{id}" is a group`)
	refs.detach(item, ref)
	return item
end

function graph.setFields(doc: Doc, id: string, fields: ItemFields): Item
	local item = graph.get(doc, id)
	checkFields(fields)
	if graph.isGroup(item) then
		assert(
			fields.status == nil
				and fields.repo == nil
				and fields.pr == nil
				and fields.who == nil
				and fields.kind == nil,
			"groups only take a label, blurb, arrange, and columns"
		)
		if fields.label then
			item.data.label = fields.label
		end
		if fields.blurb then
			item.data.blurb = if fields.blurb == "" then nil else fields.blurb
		end
		if fields.arrange or fields.columns then
			local arrange = fields.arrange or field(item, "arrange") or "auto"
			assert(fields.columns == nil or arrange == "grid", "columns only apply to a grid; pass --arrange grid")
			item.data.arrange = if arrange == "auto" then nil else arrange
			if arrange ~= "grid" then
				item.data.columns = nil
			elseif fields.columns then
				item.data.columns = fields.columns
			end
			if arrange ~= "custom" and item.data.layout == nil then
				item.data.layout = "refit"
			end
		end
		return item
	end
	assert(fields.arrange == nil and fields.columns == nil, `"{id}" is an item; only groups take arrange and columns`)
	if fields.label then
		item.data.label = fields.label
	end
	if fields.status then
		item.data.status = fields.status
	end
	if fields.who then
		item.data.who = if fields.who == "" then nil else fields.who
	end
	if fields.note then
		item.data.note = if fields.note == "" then nil else fields.note
	end
	if not graph.isNote(item) and (fields.repo or fields.pr) then
		refs.setPull(item, fields.repo, fields.pr)
	end
	if fields.kind then
		assert(not graph.isNote(item), "notes don't take a kind; make it a work item first")
		item.data.itemKind = fields.kind
		item.data.itemKind = refs.itemKind(item)
	end
	return item
end

function graph.link(doc: Doc, from: string, to: string, kind: string): Link
	assert(from ~= to, "an item can't link to itself")
	for _, id in { from, to } do
		assert(not graph.isGroup(graph.get(doc, id)), `"{id}" is a group; link the items inside it`)
	end
	for _, link in doc.links do
		if link.from == from and link.to == to then
			link.kind = kind
			return link
		end
	end
	local link: Link =
		{ id = if kind == "blocks" then `{from}>{to}` else `{from}~{to}`, from = from, to = to, kind = kind }
	table.insert(doc.links, link)
	return link
end

function graph.unlink(doc: Doc, from: string, to: string)
	local before = #doc.links
	for index = #doc.links, 1, -1 do
		local link = doc.links[index]
		if link.from == from and link.to == to then
			table.remove(doc.links, index)
		end
	end
	assert(#doc.links < before, `no link from "{from}" to "{to}"`)
end

-- Groups left with nothing inside disappear, as they do in the app.
local function pruneEmptyGroups(doc: Doc)
	local changed = true
	while changed do
		changed = false
		for index = #doc.nodes, 1, -1 do
			local item = doc.nodes[index]
			if graph.isGroup(item) then
				local hasChildren = false
				for _, other in doc.nodes do
					if other.parentId == item.id then
						hasChildren = true
						break
					end
				end
				if not hasChildren then
					table.remove(doc.nodes, index)
					changed = true
				end
			end
		end
	end
end

export type NoteOptions = { group: string?, after: string?, before: string? }

-- Adds a note. With both `after` and `before` it splices into the link between them.
function graph.addNote(doc: Doc, text: string, options: NoteOptions): Item
	assert(text ~= "", "a note needs text")
	local after = if options.after then graph.get(doc, options.after) else nil
	local before = if options.before then graph.get(doc, options.before) else nil
	local parent = options.group
	if parent then
		graph.group(doc, parent)
	elseif after then
		parent = after.parentId
	elseif before then
		parent = before.parentId
	end

	local kind = "blocks"
	if after and before then
		for index = #doc.links, 1, -1 do
			local link = doc.links[index]
			if link.from == after.id and link.to == before.id then
				kind = link.kind
				table.remove(doc.links, index)
			end
		end
	end

	local position = graph.nextSlot(doc, parent)
	if after and after.parentId == parent then
		position = { x = after.position.x + TASK_W + GAP, y = after.position.y + TASK_H + PAD }
	end
	local note: Item = {
		id = uniqueId(doc, `note-{slug(text):sub(1, 24)}`),
		type = "task",
		position = position,
		parentId = parent,
		data = json.object({ kind = "task", label = text, itemKind = "note", status = "todo" }),
	}
	table.insert(doc.nodes, note)
	if after then
		graph.link(doc, after.id, note.id, kind)
	end
	if before then
		graph.link(doc, note.id, before.id, kind)
	end
	return note
end

-- Removes an item. A note's incoming and outgoing links are reconnected so nothing loses its blocker.
function graph.remove(doc: Doc, id: string)
	local item = graph.get(doc, id)
	assert(not graph.isGroup(item), `"{id}" is a group; use ungroup instead`)
	local ins: { Link } = {}
	local outs: { Link } = {}
	for index = #doc.links, 1, -1 do
		local link = doc.links[index]
		if link.to == id then
			table.insert(ins, link)
			table.remove(doc.links, index)
		elseif link.from == id then
			table.insert(outs, link)
			table.remove(doc.links, index)
		end
	end
	if graph.isNote(item) then
		for _, i in ins do
			for _, o in outs do
				graph.link(doc, i.from, o.to, if i.kind == "blocks" and o.kind == "blocks" then "blocks" else "related")
			end
		end
	end
	for index, other in doc.nodes do
		if other.id == id then
			table.remove(doc.nodes, index)
			break
		end
	end
	pruneEmptyGroups(doc)
end

-- Wraps items that share a parent in a new group, keeping their arrangement.
function graph.makeGroup(doc: Doc, label: string, ids: { string }): Item
	assert(label ~= "", "a group needs a name")
	assert(#ids > 0, "a group needs at least one item")
	local members: { Item } = {}
	for _, id in ids do
		table.insert(members, (graph.get(doc, id)))
	end
	local parent = members[1].parentId
	for _, member in members do
		assert(member.parentId == parent, "grouped items must share a parent; move them first")
	end
	local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
	for _, member in members do
		local w, h = sizeOf(member)
		minX = math.min(minX, member.position.x)
		minY = math.min(minY, member.position.y)
		maxX = math.max(maxX, member.position.x + w)
		maxY = math.max(maxY, member.position.y + h)
	end
	local origin = { x = minX - PAD, y = minY - HEAD }
	local group: Item = {
		id = uniqueId(doc, slug(label)),
		type = "cluster",
		position = origin,
		parentId = parent,
		width = maxX - minX + PAD * 2,
		height = maxY - minY + HEAD + PAD,
		data = json.object({ kind = "cluster", label = label }),
	}
	for _, member in members do
		member.parentId = group.id
		member.position = { x = member.position.x - origin.x, y = member.position.y - origin.y }
	end
	table.insert(doc.nodes, group)
	return group
end

function graph.ungroup(doc: Doc, id: string)
	local group = graph.group(doc, id)
	for _, item in doc.nodes do
		if item.parentId == id then
			item.parentId = group.parentId
			item.position = { x = item.position.x + group.position.x, y = item.position.y + group.position.y }
		end
	end
	for index, item in doc.nodes do
		if item.id == id then
			table.remove(doc.nodes, index)
			break
		end
	end
end

-- Moves an item or group into another group, or to the top level when `groupId` is nil.
function graph.move(doc: Doc, id: string, groupId: string?)
	local item = graph.get(doc, id)
	if groupId then
		graph.group(doc, groupId)
		assert(groupId ~= id and not table.find(graph.ancestors(doc, groupId), id), "a group can't move inside itself")
	end
	if item.parentId == groupId then
		return
	end
	-- Node order doesn't matter here; the app sorts parents ahead of children on load.
	item.position = graph.nextSlot(doc, groupId)
	item.parentId = groupId
	pruneEmptyGroups(doc)
end

return table.freeze(graph)
