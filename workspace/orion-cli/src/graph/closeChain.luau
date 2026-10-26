local derive = require("@root/graph/derive")
local getItem = require("@root/graph/getItem")
local graphTypes = require("@root/graph/types")
local isWork = require("@root/graph/isWork")
local types = require("@root/types")

type ChainStep = graphTypes.ChainStep
type ClosedChain = graphTypes.ClosedChain
type Doc = types.Doc

-- Closes out a finished card and every waiting card chained to it, so their
-- Done stamps show. The chain runs both ways along blocking links and passes
-- only through finished cards, so related links and open work stop it. Each
-- card closed gets `celebrate = false`, which markCelebrations reads as closed
-- out and drops, so a card finished in the same write doesn't start waiting
-- either.
local function closeChain(doc: Doc, id: string): ClosedChain
	local item = getItem(doc, id)
	assert(isWork(item), `"{id}" isn't a work item, so it has nothing to close out`)

	local status = derive(doc).status
	assert(status[id] == "done", `"{id}" isn't done yet; finish it before closing it out`)

	local neighbors: { [string]: { string } } = {}

	for _, link in doc.links do
		if link.kind == "blocks" then
			neighbors[link.from] = neighbors[link.from] or {}
			neighbors[link.to] = neighbors[link.to] or {}
			table.insert(neighbors[link.from], link.to)
			table.insert(neighbors[link.to], link.from)
		end
	end

	local hops: { [string]: number } = { [id] = 0 }
	local queue = { id }
	local index = 1

	while index <= #queue do
		local current = queue[index]
		index += 1

		for _, nextId in neighbors[current] or {} do
			if hops[nextId] == nil and status[nextId] == "done" then
				hops[nextId] = hops[current] + 1
				table.insert(queue, nextId)
			end
		end
	end

	local cards: { [string]: types.Item } = {}

	for _, node in doc.nodes do
		if hops[node.id] ~= nil then
			cards[node.id] = node
		end
	end

	local result: ClosedChain = { closed = {}, passed = {} }

	for _, reached in queue do
		local step: ChainStep = { id = reached, hops = hops[reached] }
		local card = cards[reached]

		if reached == id or card.data.celebrate == true then
			card.data.celebrate = false
			table.insert(result.closed, step)
		else
			table.insert(result.passed, step)
		end
	end

	return result
end

return closeChain
