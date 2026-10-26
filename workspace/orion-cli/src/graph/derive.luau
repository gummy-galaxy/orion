local cardTypes = require("@root/cardTypes/types")
local getMeaning = require("@root/cardTypes/getMeaning")
local getSnoozedFacts = require("@root/github/getSnoozedFacts")
local getStringField = require("@root/getStringField")
local graphTypes = require("@root/graph/types")
local isGroup = require("@root/graph/isGroup")
local isWork = require("@root/graph/isWork")
local types = require("@root/types")

type Derived = graphTypes.Derived
type Doc = types.Doc
type GroupStats = graphTypes.GroupStats
type Item = types.Item
type Meaning = cardTypes.Meaning
type SnoozedFacts = types.SnoozedFacts

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

-- Tarjan's algorithm groups cards that wait on each other. Each group reaches
-- the work that feeds into it, so a loop counts its shared upstream once and
-- every card in it reads the same number.
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
			if isWork(tasks[id]) then
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

		upstream[id] = count - (if isWork(item) then 1 else 0)
	end

	return upstream
end

-- Status, flow, leverage, upstream work, rarity, progress for each group and
-- the whole canvas, and the work where it's your move, all served to the app
-- rather than derived there. Each card's type says how it takes part. Cards
-- that can't block, like notes and components, pass blocking through and never
-- count as work, and cards that can't be done, like components, have no
-- status. A card done by its inputs, like a gate, also passes blocking
-- through, and is done once everything it waits on is. A snoozed card keeps
-- its status and blocking, but it has no leverage and isn't ready until it
-- wakes. `now` is a UTC time in the form Orion stores; it defaults to the
-- current time.
local function derive(doc: Doc, now: string?): Derived
	local clock = now or os.date("!%Y-%m-%dT%H:%M:%SZ") :: string
	local tasks: { [string]: Item } = {}
	local meanings: { [string]: Meaning } = {}
	local parentOf: { [string]: string } = {}
	local snoozed: { [string]: string } = {}
	local pulls: { [string]: SnoozedFacts } = {}

	for _, item in doc.nodes do
		if item.type == "task" then
			tasks[item.id] = item
			meanings[item.id] = getMeaning(item) :: Meaning
			pulls[item.id] = getSnoozedFacts(item, doc.settings.checkSnoozes, clock)
		end

		if item.parentId then
			parentOf[item.id] = item.parentId
		end

		local wakesAt = getStringField(item.data.snoozedUntil)

		if isWork(item) and wakesAt and wakesAt > clock then
			snoozed[item.id] = wakesAt
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

		local meaning = meanings[id]
		local passesThrough = not meaning.canBlock or (meaning.doneWhen == "inputs" and predecessors[id] ~= nil)

		if not passesThrough then
			return getStringField(item.data.status) ~= "done"
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
		local meaning = meanings[id]

		if not meaning.canBeDone then
			continue
		end

		local recorded = getStringField(item.data.status) or "todo"
		local blockedByDeps = false

		for _, predecessor in predecessors[id] or {} do
			if isOpen(predecessor) then
				blockedByDeps = true
				break
			end
		end

		local followsInputs = meaning.doneWhen == "inputs"
			and (not meaning.canBlock or (predecessors[id] ~= nil and recorded ~= "deferred"))

		if followsInputs then
			status[id] = if isOpen(id) then "blocked" else "done"
		elseif recorded == "done" or recorded == "deferred" or recorded == "blocked" then
			status[id] = recorded
		elseif blockedByDeps then
			status[id] = "blocked"
		else
			status[id] = if recorded == "todo" then "ready" else recorded
		end
	end

	-- Links move unless they come out of work that's stuck. Cards that can't
	-- block pass on whatever reaches them, and links out of cards with no
	-- status stay still.
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

		local meaning = meanings[id]
		local incoming = predecessors[id] or {}
		-- A note fed only by components carries no work either, so its links
		-- stay still too.
		local fedOnlyByComponents = meaning.canBeDone and not meaning.canBlock and #incoming > 0

		for _, predecessor in incoming do
			if not fedOnlyByComponents then
				break
			end

			fedOnlyByComponents = flowOf(predecessor, seen) == "still"
		end

		if not meaning.canBeDone or fedOnlyByComponents then
			value = "still"
		elseif status[id] == "done" then
			value = "live"
		elseif not meaning.canBlock then
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
		if not isWork(item) or not isOpen(id) then
			continue
		end

		-- Parked work doesn't count toward what finishing something unlocks.
		local reached: { [string]: boolean } = {}
		local stack = { id }

		while #stack > 0 do
			local current = table.remove(stack) :: string

			for _, next in successors[current] or {} do
				local nextItem = tasks[next]

				if
					reached[next]
					or not nextItem
					or not isOpen(next)
					or getStringField(nextItem.data.status) == "deferred"
				then
					continue
				end

				reached[next] = true
				table.insert(stack, next)
			end
		end

		local work: { [string]: boolean } = {}
		local count = 0

		for reachedId in reached do
			if isWork(tasks[reachedId]) then
				work[reachedId] = true
				count += 1
			end
		end

		downstream[id] = work

		if not snoozed[id] then
			leverage[id] = count
		end
	end

	local upstream = countUpstream(tasks, predecessors)
	local rarity: { [string]: string } = {}

	for id, item in tasks do
		if isWork(item) then
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

	-- Progress over a set of cards, and the work they reach outside it.
	local function countStats(inside: { [string]: boolean }): GroupStats
		local stats: GroupStats = { total = 0, done = 0, ready = 0, blocked = 0, outside = 0, components = 0 }
		local outside: { [string]: boolean } = {}

		for id in inside do
			local statusValue = status[id]

			if not meanings[id].canBeDone then
				stats.components += 1
			end

			if not statusValue or not isWork(tasks[id]) then
				continue
			end

			-- Deferred work is set aside, so it doesn't hold a group short of
			-- done.
			if statusValue ~= "deferred" then
				stats.total += 1
			end

			if statusValue == "done" then
				stats.done += 1
			elseif statusValue == "ready" then
				if not snoozed[id] then
					stats.ready += 1
				end
			elseif statusValue == "blocked" then
				stats.blocked += 1
			end

			-- Leverage that lands outside the group counts toward the group's
			-- reach.
			for reachedId in downstream[id] or {} do
				if not inside[reachedId] then
					outside[reachedId] = true
				end
			end
		end

		for _ in outside do
			stats.outside += 1
		end

		return stats
	end

	local groups: { [string]: GroupStats } = {}

	for _, item in doc.nodes do
		if isGroup(item) then
			groups[item.id] = countStats(members[item.id] or {})
		end
	end

	local everything: { [string]: boolean } = {}
	local attention: { [string]: boolean } = {}

	for id, item in tasks do
		everything[id] = true

		-- It's your move on open work that can move. Blocked work waits, and
		-- snoozed work is set aside until it wakes.
		local statusValue = status[id]
		local isOpenWork = statusValue ~= "done" and statusValue ~= "deferred" and statusValue ~= "blocked"

		if isWork(item) and getStringField(item.data.who) == "you" and not snoozed[id] and isOpenWork then
			attention[id] = true
		end
	end

	return {
		status = status,
		flow = flow,
		leverage = leverage,
		upstream = upstream,
		rarity = rarity,
		groups = groups,
		canvas = countStats(everything),
		snoozed = snoozed,
		attention = attention,
		pulls = pulls,
	}
end

return derive
