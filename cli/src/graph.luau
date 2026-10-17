local json = require("@std/json")

local checkBackground = require("@root/style/checkBackground")
local checkHeader = require("@root/style/checkHeader")
local fieldValues = require("@root/fieldValues")
local findRef = require("@root/refs/findRef")
local getGithubKey = require("@root/refs/getGithubKey")
local getRefs = require("@root/refs/getRefs")
local isAssetId = require("@root/media/isAssetId")
local removeRef = require("@root/refs/removeRef")
local setRef = require("@root/refs/setRef")
local slugify = require("@root/slugify")
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
-- The band a group's header takes under its title row. The app reserves the same band.
local GROUP_HEADER_BAND = 112
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
	cover: string?,
	background: string?,
	header: string?,
	kind: string?,
	shape: string?,
	color: string?,
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

-- A component is a part of a system drawn on the canvas, like a service or a data store, rather than work.
function graph.isComponent(item: Item): boolean
	return item.type == "task" and field(item, "itemKind") == "component"
end

-- Cards that count as work. Notes and components pass blocking through and never do.
function graph.isWork(item: Item): boolean
	return item.type == "task" and not graph.isNote(item) and not graph.isComponent(item)
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

export type Progress = { total: number, done: number, ready: number, components: number }

-- Counts the work anywhere inside a group, leaving out notes and deferred work, which is set aside and doesn't
-- hold a group short of done. Components are counted on their own.
function graph.countProgress(doc: Doc, derived: Derived, groupId: string): Progress
	local progress = { total = 0, done = 0, ready = 0, components = 0 }
	for _, item in doc.nodes do
		local status = derived.status[item.id]
		local inside = item.type == "task" and table.find(graph.ancestors(doc, item.id), groupId) ~= nil

		if inside and graph.isComponent(item) then
			progress.components += 1
		elseif inside and graph.isWork(item) and status ~= "deferred" then
			progress.total += 1
			progress.done += if status == "done" then 1 else 0
			progress.ready += if status == "ready" then 1 else 0
		end
	end
	return progress
end

-- The size the app draws an item at. Groups use their stored width and height.
function graph.sizeOf(item: Item): (number, number)
	if item.type == "task" then
		return TASK_WIDTH, TASK_HEIGHT
	end

	return item.width or 320, item.height or 200
end

-- Status and leverage, matching app/src/derive.ts. Notes and components pass blocking through and never count as
-- work, and components have no status. Gates also pass blocking through, but count as work: one is done once
-- everything it waits on is.
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

		local passesThrough = not graph.isWork(item) or (graph.isGate(item) and predecessors[id] ~= nil)
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
		if graph.isComponent(item) then
			continue
		end

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
		if not graph.isWork(item) or not isOpen(id) then
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

				if graph.isWork(nextItem) then
					count += 1
				end

				table.insert(stack, next)
			end
		end

		leverage[id] = count
	end

	return { status = status, leverage = leverage }
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
-- The space above a group's cards: its title row, plus the header band when the group has a header.
function graph.headerHeight(item: Item): number
	local header = item.data.header

	if type(header) == "string" and header:match("%S") then
		return GROUP_HEADER_HEIGHT + GROUP_HEADER_BAND
	end

	return GROUP_HEADER_HEIGHT
end

function graph.nextSlot(doc: Doc, parentId: string?): Position
	local right: number? = nil
	local top: number? = nil

	for _, item in doc.nodes do
		if item.parentId == parentId then
			local width = graph.sizeOf(item)
			right = math.max(right or -math.huge, item.position.x + width)
			top = math.min(top or math.huge, item.position.y)
		end
	end

	if right == nil or top == nil then
		return if parentId
			then { x = GROUP_PADDING, y = graph.headerHeight(graph.get(doc, parentId)) }
			else { x = 0, y = 0 }
	end

	return { x = (right :: number) + (if parentId then ITEM_GAP else ITEM_GAP * 2), y = top :: number }
end

local function overlapsSibling(doc: Doc, parentId: string?, position: Position, width: number, height: number): boolean
	local margin = ITEM_GAP / 2

	for _, item in doc.nodes do
		if item.parentId == parentId then
			local itemWidth, itemHeight = graph.sizeOf(item)

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
	if kind == "gate" or kind == "component" then
		return kind
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
		`kind must be one of {table.concat(fieldValues.kinds, ", ")}`
	)
	assert(
		fields.arrange == nil or table.find(fieldValues.arrangements, fields.arrange),
		`arrange must be one of {table.concat(fieldValues.arrangements, ", ")}`
	)
	assert(
		fields.shape == nil or fields.shape == "" or table.find(fieldValues.shapes, fields.shape),
		`shape must be one of {table.concat(fieldValues.shapes, ", ")}`
	)
	assert(
		fields.color == nil or fields.color == "" or table.find(fieldValues.colors, fields.color),
		`color must be one of {table.concat(fieldValues.colors, ", ")}`
	)
	assert(
		fields.cover == nil or fields.cover == "" or isAssetId(fields.cover),
		"cover must be an image asset id, such as the asset from orion media insert"
	)

	if fields.background and fields.background ~= "" then
		checkBackground(fields.background)
	end

	if fields.header and fields.header ~= "" then
		checkHeader(fields.header)
	end
end

-- Sets or clears (with an empty value) a component's shape and color.
local function setLook(item: Item, fields: ItemFields)
	if fields.shape then
		assert(graph.isComponent(item), "only components take a shape")
		item.data.shape = if fields.shape == "" then nil else fields.shape
	end

	if fields.color then
		assert(graph.isComponent(item), "only components and groups take a color")
		item.data.color = if fields.color == "" then nil else fields.color
	end
end

export type AddOptions = ItemFields & { group: string? }

function graph.addItem(doc: Doc, label: string, options: AddOptions): Item
	assert(label ~= "", "an item needs a label")
	checkFields(options)
	assert(options.shape == nil or options.kind == nil or options.kind == "component", "only components take a shape")
	assert(options.pr == nil or options.repo ~= nil, "pr needs a repository as owner/name")

	if options.group then
		graph.group(doc, options.group)
	end

	local base = if options.repo and options.pr
		then `{slugify(options.repo :: string)}-{options.pr}`
		else slugify(label)
	local data: json.Object = json.object({
		kind = "task",
		label = label,
		-- A shape only fits a component, so giving one makes the item a component.
		itemKind = itemKindFor(options.repo, options.pr, if options.shape then "component" else options.kind),
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
	setLook(item, options)
	table.insert(doc.nodes, item)
	return item
end

function graph.addImage(doc: Doc, label: string, extension: string, workspace: string, group: string?): Item
	assert(label ~= "", "an image needs a label")
	if group then
		graph.group(doc, group)
	end
	local id = uniqueId(doc, `image-{slugify(label)}`)
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

-- Adding or removing a group's header moves its top edge up or down and keeps every card where it is on the canvas,
-- as the app does when it refits a group.
local function resizeHeader(doc: Doc, group: Item, delta: number)
	if delta == 0 then
		return
	end

	group.position = { x = group.position.x, y = group.position.y - delta }

	if group.height then
		group.height = (group.height :: number) + delta
	end

	for _, item in doc.nodes do
		if item.parentId == group.id then
			item.position = { x = item.position.x, y = item.position.y + delta }
		end
	end
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
				and fields.kind == nil
				and fields.shape == nil,
			"groups only take a label, blurb, arrange, cover, background, header, and color"
		)

		if fields.color then
			item.data.color = if fields.color == "" then nil else fields.color
		end

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

		if fields.cover then
			item.data.cover = if fields.cover == "" then nil else fields.cover
		end

		if fields.background then
			item.data.background = if fields.background == "" then nil else fields.background
		end

		if fields.header then
			local before = graph.headerHeight(item)
			item.data.header = if fields.header == "" then nil else fields.header
			resizeHeader(doc, item, graph.headerHeight(item) - before)
		end

		return item
	end

	assert(fields.arrange == nil, `"{id}" is an item; only groups take an arrangement`)
	assert(fields.blurb == nil, `"{id}" is an item; only groups take a blurb`)
	assert(
		fields.cover == nil and fields.background == nil and fields.header == nil,
		`"{id}" is an item; only groups take a cover, background, or header`
	)
	if fields.label then
		item.data.label = fields.label
	end

	if fields.status then
		item.data.status = fields.status
		item.data.deferredByClosedPull = nil
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

	-- As with add, giving a card a shape makes it a component.
	local givenKind = fields.kind
		or (if fields.shape and fields.shape ~= "" and not graph.isNote(item) then "component" else nil)

	if not graph.isNote(item) and (fields.repo or fields.pr or givenKind) then
		local repo = field(item, "repo")
		local pr = findRef(item, "pull")
		local kind = givenKind
			or (if graph.isGate(item) or graph.isComponent(item) then field(item, "itemKind") else nil)
		item.data.itemKind = itemKindFor(repo, if pr then 1 else nil, kind)
	end

	-- Work isn't drawn with a shape or tint, so a component turned into work drops them.
	if not graph.isComponent(item) then
		item.data.shape = nil
		item.data.color = nil
	end

	setLook(item, fields)
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

	graph.refreshItemKind(item)
	return item
end

-- Recomputes an item's kind from its repository, pull request, and gate status after its refs change.
function graph.refreshItemKind(item: Item)
	if graph.isNote(item) or graph.isComponent(item) then
		return
	end

	local kind = if graph.isGate(item) then "gate" else nil
	item.data.itemKind = itemKindFor(field(item, "repo"), if findRef(item, "pull") then 1 else nil, kind)
end

-- Links two items. A label names what the link carries, like "HTTP" in a system diagram; an empty one clears it,
-- and leaving it out keeps the label an existing link already has.
function graph.link(doc: Doc, from: string, to: string, kind: string, label: string?): Link
	assert(from ~= to, "an item can't link to itself")

	for _, id in { from, to } do
		assert(not graph.isGroup(graph.get(doc, id)), `"{id}" is a group; link the items inside it`)
	end

	local text = if label then label:match("^%s*(.-)%s*$") else nil

	for _, link in doc.links do
		if link.from == from and link.to == to then
			link.kind = kind

			if text then
				link.label = if text == "" then nil else text
			end

			return link
		end
	end

	local link: Link =
		{ id = if kind == "blocks" then `{from}>{to}` else `{from}~{to}`, from = from, to = to, kind = kind }

	if text and text ~= "" then
		link.label = text
	end

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

	-- The label stays with the half that leaves the original source.
	graph.unlink(doc, from, to)
	graph.link(doc, from, id, existing.kind, existing.label)
	graph.link(doc, id, to, existing.kind)
end

-- Removes a group that an edit left with nothing inside, then checks the group that holds it the same way. Only groups
-- the edit emptied go, so a group made empty on purpose, such as by group create, stays until something lands in it.
local function pruneEmptied(doc: Doc, groupId: string?)
	local current = groupId

	while current do
		local group = graph.find(doc, current)

		if group == nil or not graph.isGroup(group) then
			return
		end

		for _, other in doc.nodes do
			if other.parentId == current then
				return
			end
		end

		for index, node in doc.nodes do
			if node.id == current then
				table.remove(doc.nodes, index)
				break
			end
		end

		current = group.parentId
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
		id = uniqueId(doc, `note-{slugify(text, 24)}`),
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
	assert(not graph.isGroup(item), `"{id}" is a group; use group ungroup or group remove instead`)
	local parentId = item.parentId
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

	pruneEmptied(doc, parentId)
end

-- Asks the app to tidy a group whose members changed. A pending marker already places it, so it is kept, and a
-- custom group is left as the user arranged it.
local function markForRefit(group: Item)
	if group.data.layout == nil and group.data.arrange ~= "custom" then
		group.data.layout = "refit"
	end
end

-- Marks a group for the app to lay out in place, as `orion group tidy` does. A pending marker is kept, since the app already
-- places that group. A custom group is marked too; the app clears the marker and leaves its arrangement alone.
function graph.markForTidy(doc: Doc, id: string)
	local group = graph.group(doc, id)

	if group.data.layout == nil then
		group.data.layout = "refit"
	end
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
		local width, height = graph.sizeOf(member)
		minimumX = math.min(minimumX, member.position.x)
		minimumY = math.min(minimumY, member.position.y)
		maximumX = math.max(maximumX, member.position.x + width)
		maximumY = math.max(maximumY, member.position.y + height)
	end

	local origin = { x = minimumX - GROUP_PADDING, y = minimumY - GROUP_HEADER_HEIGHT }
	local group: Item = {
		id = uniqueId(doc, slugify(label)),
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

	markForRefit(group)
	table.insert(doc.nodes, group)
	return group
end

-- Makes an empty group, inside `parentId` when given. Its size is one card's worth, so layout checks leave room for it.
function graph.createGroup(doc: Doc, label: string, parentId: string?): Item
	assert(label ~= "", "a group needs a name")

	if parentId then
		graph.group(doc, parentId)
	end

	local group: Item = {
		id = uniqueId(doc, slugify(label)),
		type = "cluster",
		position = graph.nextSlot(doc, parentId),
		parentId = parentId,
		width = TASK_WIDTH + GROUP_PADDING * 2,
		height = TASK_HEIGHT + GROUP_HEADER_HEIGHT + GROUP_PADDING,
		data = json.object({ kind = "cluster", label = label }),
	}
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

	if group.parentId then
		markForRefit(graph.group(doc, group.parentId))
	end

	for index, item in doc.nodes do
		if item.id == id then
			table.remove(doc.nodes, index)
			break
		end
	end
end

-- Everything inside a group at any depth, parents before their children.
function graph.contents(doc: Doc, id: string): { Item }
	local contents: { Item } = {}
	local parents = { id }
	local index = 1

	while index <= #parents do
		for _, item in doc.nodes do
			if item.parentId == parents[index] then
				table.insert(contents, item)

				if graph.isGroup(item) then
					table.insert(parents, item.id)
				end
			end
		end

		index += 1
	end

	return contents
end

-- Removes a group with everything inside it. Each card goes the way `remove` takes it, so a note's links reconnect
-- around it, and a parent left empty disappears.
function graph.removeGroup(doc: Doc, id: string)
	local parentId = graph.group(doc, id).parentId
	local groupIds = { [id] = true }

	for _, item in graph.contents(doc, id) do
		if graph.isGroup(item) then
			groupIds[item.id] = true
		elseif graph.find(doc, item.id) then
			graph.remove(doc, item.id)
		end
	end

	for index = #doc.nodes, 1, -1 do
		if groupIds[doc.nodes[index].id] then
			table.remove(doc.nodes, index)
		end
	end

	pruneEmptied(doc, parentId)
end

-- Takes a ref off an item. A kind narrows the match when the same key could name an issue and a pull request.
function graph.detachRef(doc: Doc, id: string, key: string, kind: string?): Item
	local item = graph.get(doc, id)
	assert(not graph.isGroup(item), "groups don't take refs")
	local matched = false

	for _, ref in getRefs(item) do
		if ref.key:lower() == key:lower() and (kind == nil or ref.kind == kind) then
			removeRef(item, ref.kind, ref.key)
			matched = true
		end
	end

	assert(matched, `"{id}" has no ref {key}`)
	graph.refreshItemKind(item)
	return item
end

-- The recorded status of every card, read before a write so markCelebrations can see what changed.
function graph.recordedStatuses(doc: Doc): { [string]: string }
	local statuses: { [string]: string } = {}

	for _, item in doc.nodes do
		if item.type == "task" then
			statuses[item.id] = field(item, "status") or "todo"
		end
	end

	return statuses
end

-- Sets `celebrate` on a card that changed to done, so the app can celebrate it, and clears it when the card is
-- reopened. Cards created done and notes never get the flag, and cards finished before the flag existed don't have it.
function graph.markCelebrations(doc: Doc, previous: { [string]: string })
	for _, item in doc.nodes do
		if item.type == "task" and not graph.isNote(item) then
			local status = field(item, "status")
			local wasOpen = previous[item.id] ~= nil and previous[item.id] ~= "done"

			if status == "done" and wasOpen then
				item.data.celebrate = true
			elseif status ~= "done" then
				item.data.celebrate = nil
			end
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

	local previousParent = item.parentId

	-- Node order doesn't matter here; the app sorts parents ahead of children on load.
	item.position = graph.nextSlot(doc, groupId)
	item.parentId = groupId

	if groupId then
		markForRefit(graph.group(doc, groupId))
	end

	pruneEmptied(doc, previousParent)
end

return table.freeze(graph)
