local json = require("@std/json")

local fieldValues = require("@root/fieldValues")
local findRef = require("@root/refs/findRef")
local getGithubKey = require("@root/refs/getGithubKey")
local removeRef = require("@root/refs/removeRef")
local setRef = require("@root/refs/setRef")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item
type Link = types.Link
type Position = types.Position

-- Card and group sizes match the app so CLI placements line up with its layout.
local TASK_WIDTH = 216
local TASK_HEIGHT = 72
local GROUP_PADDING = 32
local GROUP_HEADER_HEIGHT = 78
local ITEM_GAP = 48

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
	arrange: string?,
	kind: string?,
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
	local ancestors = {}
	local current = graph.find(doc, id)

	while current and current.parentId do
		table.insert(ancestors, current.parentId)
		current = graph.find(doc, current.parentId)
	end

	return ancestors
end

export type Progress = { total: number, done: number, ready: number }

-- Counts the work anywhere inside a group, leaving out notes.
function graph.countProgress(doc: Doc, derived: Derived, groupId: string): Progress
	local progress = { total = 0, done = 0, ready = 0 }
	for _, item in doc.nodes do
		if item.type == "task" and not graph.isNote(item) and table.find(graph.ancestors(doc, item.id), groupId) then
			progress.total += 1
			local status = derived.status[item.id]
			progress.done += if status == "done" then 1 else 0
			progress.ready += if status == "ready" then 1 else 0
		end
	end
	return progress
end

local function sizeOf(item: Item): (number, number)
	if item.type == "task" then
		return TASK_WIDTH, TASK_HEIGHT
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

	local predecessors: { [string]: { string } } = {}
	local successors: { [string]: { string } } = {}

	for _, link in doc.links do
		if link.kind == "blocks" then
			predecessors[link.to] = predecessors[link.to] or {}
			successors[link.from] = successors[link.from] or {}
			table.insert(predecessors[link.to], link.from)
			table.insert(successors[link.from], link.to)
		end
	end

	local noteOpen: { [string]: boolean } = {}

	local function isOpen(id: string, seen: { [string]: boolean }?): boolean
		local item = tasks[id]

		if not item then
			return false
		end

		local passesThrough = graph.isNote(item) or (graph.isGate(item) and predecessors[id] ~= nil)
		if not passesThrough then
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

		for _, predecessor in predecessors[id] or {} do
			if isOpen(predecessor, visited) then
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

		for _, predecessor in predecessors[id] or {} do
			if isOpen(predecessor) then
				blockedByDeps = true
				break
			end
		end

		if graph.isNote(item) or (graph.isGate(item) and predecessors[id] and recorded ~= "deferred") then
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

			for _, next in successors[current] or {} do
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

	local suffix = 2

	while graph.find(doc, `{base}-{suffix}`) do
		suffix += 1
	end

	return `{base}-{suffix}`
end

-- The next free spot to the right of a parent's children, or of the top level.
function graph.nextSlot(doc: Doc, parentId: string?): Position
	local right: number? = nil
	local top: number? = nil

	for _, item in doc.nodes do
		if item.parentId == parentId then
			local width = sizeOf(item)
			right = math.max(right or -math.huge, item.position.x + width)
			top = math.min(top or math.huge, item.position.y)
		end
	end

	if right == nil or top == nil then
		return if parentId then { x = GROUP_PADDING, y = GROUP_HEADER_HEIGHT } else { x = 0, y = 0 }
	end

	return { x = (right :: number) + (if parentId then ITEM_GAP else ITEM_GAP * 2), y = top :: number }
end

local function overlapsSibling(doc: Doc, parentId: string?, position: Position, width: number, height: number): boolean
	local margin = ITEM_GAP / 2

	for _, item in doc.nodes do
		if item.parentId == parentId then
			local itemWidth, itemHeight = sizeOf(item)

			if
				position.x < item.position.x + itemWidth + margin
				and item.position.x < position.x + width + margin
				and position.y < item.position.y + itemHeight + margin
				and item.position.y < position.y + height + margin
			then
				return true
			end
		end
	end

	return false
end

-- The first spot at or below a preferred one that no sibling covers.
local function freeSpotBelow(doc: Doc, parentId: string?, preferred: Position): Position
	local position = { x = preferred.x, y = preferred.y }

	while overlapsSibling(doc, parentId, position, TASK_WIDTH, TASK_HEIGHT) do
		position.y += TASK_HEIGHT + ITEM_GAP
	end

	return position
end

local function itemKindFor(repo: string?, pr: number?, kind: string?): string
	if kind == "gate" then
		return "gate"
	end

	if repo and pr then
		return "pr"
	end

	return if repo then "placeholder" else "step"
end

local function checkFields(fields: ItemFields)
	assert(
		fields.repo == nil or fields.repo == "" or fields.repo:match("^[%w_.%-]+/[%w_.%-]+$"),
		"repo must be owner/name"
	)
	assert(fields.pr == nil or fields.repo ~= "", "pr needs a repository as owner/name")
	assert(
		fields.status == nil or table.find(fieldValues.statuses, fields.status),
		`status must be one of {table.concat(fieldValues.statuses, ", ")}`
	)
	assert(
		fields.who == nil or fields.who == "" or table.find(fieldValues.who, fields.who),
		`who must be one of {table.concat(fieldValues.who, ", ")}`
	)
	assert(fields.pr == nil or (fields.pr > 0 and fields.pr % 1 == 0), "pr must be a positive whole number")
	assert(
		fields.kind == nil or table.find(fieldValues.kinds, fields.kind),
		`kind must be {table.concat(fieldValues.kinds, " or ")}`
	)
	assert(
		fields.arrange == nil or table.find(fieldValues.arrangements, fields.arrange),
		`arrange must be one of {table.concat(fieldValues.arrangements, ", ")}`
	)
end

export type AddOptions = ItemFields & { group: string? }

function graph.addItem(doc: Doc, label: string, options: AddOptions): Item
	assert(label ~= "", "an item needs a label")
	checkFields(options)
	assert(options.pr == nil or options.repo ~= nil, "pr needs a repository as owner/name")

	if options.group then
		graph.group(doc, options.group)
	end

	local base = if options.repo and options.pr then `{slug(options.repo :: string)}-{options.pr}` else slug(label)
	local data: json.Object = json.object({
		kind = "task",
		label = label,
		itemKind = itemKindFor(options.repo, options.pr, options.kind),
		status = options.status or "todo",
	})
	data.repo = options.repo
	data.note = options.note
	data.who = if options.who == "" then nil else options.who
	local item: Item = {
		id = uniqueId(doc, base),
		type = "task",
		position = graph.nextSlot(doc, options.group),
		parentId = options.group,
		data = data,
	}
	if options.pr and options.repo then
		local owner, name = options.repo:match("^([^/]+)/([^/]+)$")
		setRef(item, {
			source = "github",
			kind = "pull",
			key = getGithubKey(assert(owner), assert(name), `#{options.pr}`),
			url = `https://github.com/{options.repo}/pull/{options.pr}`,
		})
	end
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

function graph.setFields(doc: Doc, id: string, fields: ItemFields): Item
	local item = graph.get(doc, id)
	checkFields(fields)

	if graph.isGroup(item) then
		assert(
			fields.status == nil
				and fields.repo == nil
				and fields.pr == nil
				and fields.who == nil
				and fields.note == nil
				and fields.kind == nil,
			"groups only take a label, blurb, and arrange"
		)

		if fields.label then
			item.data.label = fields.label
		end

		if fields.blurb then
			item.data.blurb = if fields.blurb == "" then nil else fields.blurb
		end

		if fields.arrange then
			item.data.arrange = if fields.arrange == "auto" then nil else fields.arrange
			if fields.arrange ~= "custom" and item.data.layout == nil then
				item.data.layout = "refit"
			end
		end

		return item
	end

	assert(fields.arrange == nil, `"{id}" is an item; only groups take an arrangement`)
	assert(fields.blurb == nil, `"{id}" is an item; only groups take a blurb`)
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

	if fields.repo then
		item.data.repo = if fields.repo == "" then nil else fields.repo
		if fields.repo == "" then
			removeRef(item, "pull")
		end
	end

	if fields.pr then
		local repo = field(item, "repo")
		assert(repo, "pr needs a repository as owner/name")
		local owner, name = repo:match("^([^/]+)/([^/]+)$")
		removeRef(item, "pull")
		setRef(item, {
			source = "github",
			kind = "pull",
			key = getGithubKey(assert(owner), assert(name), `#{fields.pr}`),
			url = `https://github.com/{repo}/pull/{fields.pr}`,
		})
	end

	if fields.kind then
		assert(not graph.isNote(item), "notes don't take a kind; make it a work item first")
	end

	if not graph.isNote(item) and (fields.repo or fields.pr or fields.kind) then
		local repo = field(item, "repo")
		local pr = findRef(item, "pull")
		local kind = fields.kind or (if graph.isGate(item) then "gate" else nil)
		item.data.itemKind = itemKindFor(repo, if pr then 1 else nil, kind)
	end

	return item
end

-- Attaches outside work to an item. The repository fills in only when the item has none yet.
function graph.attachRef(doc: Doc, id: string, resolved: types.ResolvedRef): Item
	local item = graph.get(doc, id)
	assert(not graph.isGroup(item), "groups don't take refs; attach it to an item")
	setRef(item, resolved.ref)

	if resolved.repo and item.data.repo == nil then
		item.data.repo = resolved.repo
	end

	if not graph.isNote(item) then
		local kind = if graph.isGate(item) then "gate" else nil
		item.data.itemKind = itemKindFor(field(item, "repo"), if findRef(item, "pull") then 1 else nil, kind)
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

function graph.insertBetween(doc: Doc, id: string, from: string, to: string)
	assert(id ~= from and id ~= to, "an item can't link to itself")
	for _, itemId in { from, id, to } do
		assert(not graph.isGroup(graph.get(doc, itemId)), `"{itemId}" is a group; link the items inside it`)
	end

	local existing: Link?
	for _, link in doc.links do
		if link.from == from and link.to == to then
			existing = link
			break
		end
	end
	assert(existing, `no link from "{from}" to "{to}"`)

	graph.unlink(doc, from, to)
	graph.link(doc, from, id, existing.kind)
	graph.link(doc, id, to, existing.kind)
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

-- Adds a note. An existing link keeps its kind when the note splits it.
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

	local hasExistingLink = false
	if after and before then
		for _, link in doc.links do
			if link.from == after.id and link.to == before.id then
				hasExistingLink = true
				break
			end
		end
	end

	local position = graph.nextSlot(doc, parent)

	if after and after.parentId == parent then
		position = freeSpotBelow(doc, parent, {
			x = after.position.x + TASK_WIDTH + ITEM_GAP,
			y = after.position.y + TASK_HEIGHT + GROUP_PADDING,
		})
	end

	local note: Item = {
		id = uniqueId(doc, `note-{slug(text):sub(1, 24)}`),
		type = "task",
		position = position,
		parentId = parent,
		data = json.object({ kind = "task", label = text, itemKind = "note", status = "todo" }),
	}
	table.insert(doc.nodes, note)

	if after and before and hasExistingLink then
		graph.insertBetween(doc, note.id, after.id, before.id)
	else
		if after then
			graph.link(doc, after.id, note.id, "blocks")
		end
		if before then
			graph.link(doc, note.id, before.id, "blocks")
		end
	end

	return note
end

function graph.checkReconnect(doc: Doc, id: string)
	local incoming, outgoing = 0, 0
	for _, link in doc.links do
		if link.to == id then
			incoming += 1
		elseif link.from == id then
			outgoing += 1
		end
	end
	assert(incoming <= 1 and outgoing <= 1, `"{id}" needs at most one incoming and one outgoing link to reconnect`)
end

-- A note's incoming and outgoing links are reconnected so nothing loses its blocker.
function graph.remove(doc: Doc, id: string, reconnect: boolean?)
	local item = graph.get(doc, id)
	assert(not graph.isGroup(item), `"{id}" is a group; use ungroup instead`)
	if reconnect then
		graph.checkReconnect(doc, id)
	end
	local incomingLinks: { Link } = {}
	local outgoingLinks: { Link } = {}

	for index = #doc.links, 1, -1 do
		local link = doc.links[index]

		if link.to == id then
			table.insert(incomingLinks, link)
			table.remove(doc.links, index)
		elseif link.from == id then
			table.insert(outgoingLinks, link)
			table.remove(doc.links, index)
		end
	end

	if graph.isNote(item) or reconnect then
		for _, incomingLink in incomingLinks do
			for _, outgoingLink in outgoingLinks do
				graph.link(
					doc,
					incomingLink.from,
					outgoingLink.to,
					if incomingLink.kind == "blocks" and outgoingLink.kind == "blocks" then "blocks" else "related"
				)
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

	local minimumX, minimumY, maximumX, maximumY = math.huge, math.huge, -math.huge, -math.huge

	for _, member in members do
		local width, height = sizeOf(member)
		minimumX = math.min(minimumX, member.position.x)
		minimumY = math.min(minimumY, member.position.y)
		maximumX = math.max(maximumX, member.position.x + width)
		maximumY = math.max(maximumY, member.position.y + height)
	end

	local origin = { x = minimumX - GROUP_PADDING, y = minimumY - GROUP_HEADER_HEIGHT }
	local group: Item = {
		id = uniqueId(doc, slug(label)),
		type = "cluster",
		position = origin,
		parentId = parent,
		width = maximumX - minimumX + GROUP_PADDING * 2,
		height = maximumY - minimumY + GROUP_HEADER_HEIGHT + GROUP_PADDING,
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
