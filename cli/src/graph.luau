local json = require("@std/json")

local fieldValues = require("@root/fieldValues")
local findRef = require("@root/refs/findRef")
local getGithubKey = require("@root/refs/getGithubKey")
local getRefs = require("@root/refs/getRefs")
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

export type GroupStats = { total: number, done: number, ready: number, blocked: number, outside: number }

export type Derived = {
	status: { [string]: string },
	flow: { [string]: string },
	leverage: { [string]: number },
	upstream: { [string]: number },
	rarity: { [string]: string },
	groups: { [string]: GroupStats },
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

-- Counts the work anywhere inside a group, leaving out notes and deferred work, which is set aside and doesn't
-- hold a group short of done.
function graph.countProgress(derived: Derived, groupId: string): Progress
	local stats = derived.groups[groupId]
	return if stats
		then { total = stats.total, done = stats.done, ready = stats.ready }
		else { total = 0, done = 0, ready = 0 }
end

-- The size the app draws an item at. Groups use their stored width and height.
function graph.sizeOf(item: Item): (number, number)
	if item.type == "task" then
		return TASK_WIDTH, TASK_HEIGHT
	end

	return item.width or 320, item.height or 200
end

local UNCOMMON_UPSTREAM = 4
local RARE_UPSTREAM = 8
local MYTHIC_UPSTREAM = 14

-- Rarity grows with how much work feeds into a card.
local function rarityOf(upstream: number): string
	if upstream >= MYTHIC_UPSTREAM then
		return "mythic"
	elseif upstream >= RARE_UPSTREAM then
		return "rare"
	elseif upstream >= UNCOMMON_UPSTREAM then
		return "uncommon"
	end

	return "common"
end

-- Tarjan's algorithm groups cards that wait on each other. Each group reaches the work that feeds into it, so
-- a loop counts its shared upstream once and every card in it reads the same number.
local function countUpstream(tasks: { [string]: Item }, predecessors: { [string]: { string } }): { [string]: number }
	local indices: { [string]: number } = {}
	local lowLinks: { [string]: number } = {}
	local onStack: { [string]: boolean } = {}
	local stack: { string } = {}
	local components: { { string } } = {}
	local componentOf: { [string]: number } = {}
	local indexCount = 0

	local function visit(id: string)
		indexCount += 1
		indices[id] = indexCount
		lowLinks[id] = indexCount
		table.insert(stack, id)
		onStack[id] = true

		for _, predecessor in predecessors[id] or {} do
			if not tasks[predecessor] then
				continue
			end

			if not indices[predecessor] then
				visit(predecessor)
				lowLinks[id] = math.min(lowLinks[id], lowLinks[predecessor])
			elseif onStack[predecessor] then
				lowLinks[id] = math.min(lowLinks[id], indices[predecessor])
			end
		end

		if lowLinks[id] ~= indices[id] then
			return
		end

		local component: { string } = {}
		local member: string

		repeat
			member = table.remove(stack) :: string
			onStack[member] = nil
			componentOf[member] = #components + 1
			table.insert(component, member)
		until member == id

		table.insert(components, component)
	end

	for id in tasks do
		if not indices[id] then
			visit(id)
		end
	end

	local reaches: { [number]: { [string]: boolean } } = {}

	local function reachOf(componentIndex: number): { [string]: boolean }
		local known = reaches[componentIndex]

		if known then
			return known
		end

		local reach: { [string]: boolean } = {}

		for _, id in components[componentIndex] do
			if not graph.isNote(tasks[id]) then
				reach[id] = true
			end

			for _, predecessor in predecessors[id] or {} do
				local previous = componentOf[predecessor]

				if previous ~= nil and previous ~= componentIndex then
					for ancestor in reachOf(previous) do
						reach[ancestor] = true
					end
				end
			end
		end

		reaches[componentIndex] = reach
		return reach
	end

	local upstream: { [string]: number } = {}

	for id, item in tasks do
		local count = 0

		for _ in reachOf(componentOf[id]) do
			count += 1
		end

		upstream[id] = count - (if graph.isNote(item) then 0 else 1)
	end

	return upstream
end

-- Status, flow, leverage, upstream work, rarity, and group progress, all served to the app rather than derived there.
-- Notes pass blocking through and never count as work. Gates also pass blocking through, but count as work: one
-- is done once everything it waits on is.
function graph.derive(doc: Doc): Derived
	local tasks: { [string]: Item } = {}
	local parentOf: { [string]: string } = {}

	for _, item in doc.nodes do
		if item.type == "task" then
			tasks[item.id] = item
		end

		if item.parentId then
			parentOf[item.id] = item.parentId
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

	-- Links move unless they come out of work that's stuck. Notes pass on whatever reaches them.
	local flow: { [string]: string } = {}

	local function flowOf(id: string, seen: { [string]: boolean }): string
		local known = flow[id]

		if known then
			return known
		end

		local item = tasks[id]

		-- Something that isn't a card has no status, so links out of it move.
		if not item then
			return "live"
		end

		if seen[id] then
			return "held"
		end

		seen[id] = true
		local value: string

		if status[id] == "done" then
			value = "live"
		elseif graph.isNote(item) then
			value = "held"

			for _, predecessor in predecessors[id] or {} do
				if flowOf(predecessor, seen) == "live" then
					value = "live"
					break
				end
			end
		else
			value = if status[id] == "blocked" or status[id] == "deferred" then "held" else "live"
		end

		flow[id] = value
		return value
	end

	for id in tasks do
		flowOf(id, {})
	end

	local leverage: { [string]: number } = {}
	local downstream: { [string]: { [string]: boolean } } = {}

	for id, item in tasks do
		if graph.isNote(item) or not isOpen(id) then
			continue
		end

		-- Parked work doesn't count toward what finishing something unlocks.
		local reached: { [string]: boolean } = {}
		local stack = { id }

		while #stack > 0 do
			local current = table.remove(stack) :: string

			for _, next in successors[current] or {} do
				local nextItem = tasks[next]

				if reached[next] or not nextItem or not isOpen(next) or field(nextItem, "status") == "deferred" then
					continue
				end

				reached[next] = true
				table.insert(stack, next)
			end
		end

		local count = 0

		for reachedId in reached do
			if not graph.isNote(tasks[reachedId]) then
				count += 1
			end
		end

		leverage[id] = count
		downstream[id] = reached
	end

	local upstream = countUpstream(tasks, predecessors)
	local rarity: { [string]: string } = {}

	for id, item in tasks do
		if not graph.isNote(item) then
			rarity[id] = rarityOf(upstream[id])
		end
	end

	-- Each group's members are every card below it, however deeply nested.
	local members: { [string]: { [string]: boolean } } = {}

	for id in tasks do
		local current = parentOf[id]

		for _ = 1, #doc.nodes do
			if not current then
				break
			end

			members[current] = members[current] or {}
			members[current][id] = true
			current = parentOf[current]
		end
	end

	local groups: { [string]: GroupStats } = {}

	for _, item in doc.nodes do
		if not graph.isGroup(item) then
			continue
		end

		local stats: GroupStats = { total = 0, done = 0, ready = 0, blocked = 0, outside = 0 }
		local inside = members[item.id] or {}
		local outside: { [string]: boolean } = {}

		for id in inside do
			local statusValue = status[id]

			if not statusValue or graph.isNote(tasks[id]) then
				continue
			end

			-- Deferred work is set aside, so it doesn't hold a group short of done.
			if statusValue ~= "deferred" then
				stats.total += 1
			end

			if statusValue == "done" then
				stats.done += 1
			elseif statusValue == "ready" then
				stats.ready += 1
			elseif statusValue == "blocked" then
				stats.blocked += 1
			end

			-- Leverage that lands outside the group counts toward the group's reach.
			for reachedId in downstream[id] or {} do
				if not inside[reachedId] and not graph.isNote(tasks[reachedId]) then
					outside[reachedId] = true
				end
			end
		end

		for _ in outside do
			stats.outside += 1
		end

		groups[item.id] = stats
	end

	return { status = status, flow = flow, leverage = leverage, upstream = upstream, rarity = rarity, groups = groups }
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
			local width = graph.sizeOf(item)
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

	graph.refreshItemKind(item)
	return item
end

-- Recomputes an item's kind from its repository, pull request, and gate status after its refs change.
function graph.refreshItemKind(item: Item)
	if graph.isNote(item) then
		return
	end

	local kind = if graph.isGate(item) then "gate" else nil
	item.data.itemKind = itemKindFor(field(item, "repo"), if findRef(item, "pull") then 1 else nil, kind)
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
	assert(not graph.isGroup(item), `"{id}" is a group; use ungroup or group remove instead`)
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

-- Asks the app to tidy a group whose members changed. A pending marker already places it, so it is kept, and a
-- custom group is left as the user arranged it.
local function markForRefit(group: Item)
	if group.data.layout == nil and group.data.arrange ~= "custom" then
		group.data.layout = "refit"
	end
end

-- Marks a group for the app to lay out in place, as `orion tidy` does. A pending marker is kept, since the app already
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

	markForRefit(group)
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
	graph.group(doc, id)
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

	pruneEmptyGroups(doc)
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

	-- Node order doesn't matter here; the app sorts parents ahead of children on load.
	item.position = graph.nextSlot(doc, groupId)
	item.parentId = groupId

	if groupId then
		markForRefit(graph.group(doc, groupId))
	end

	pruneEmptyGroups(doc)
end

return table.freeze(graph)
