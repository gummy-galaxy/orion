local copyValue = require("@root/operations/copyValue")
local linkKey = require("@root/operations/linkKey")
local operationTypes = require("@root/operations/types")
local sameValue = require("@root/operations/sameValue")
local types = require("@root/types")

type Doc = types.Doc
type Restore = operationTypes.Restore
type Snapshot = operationTypes.Snapshot

-- The restore that turns the document back into `before`: every item or link that changed or went missing comes
-- back as it was, and every one that's new is removed.
local function diffDocs(before: Snapshot, doc: Doc): Restore
	local restore: Restore = { nodes = {}, removedNodes = {}, links = {}, removedLinks = {} }
	local currentNodes = {}

	for _, item in doc.nodes do
		currentNodes[item.id] = item
	end

	for id, saved in before.nodes do
		local current = currentNodes[id]

		if current == nil or not sameValue(current, saved.item) then
			table.insert(restore.nodes, { index = saved.index, item = copyValue(saved.item) })
		end
	end

	for id in currentNodes do
		if before.nodes[id] == nil then
			table.insert(restore.removedNodes, id)
		end
	end

	local currentLinks = {}

	for _, link in doc.links do
		currentLinks[linkKey(link.from, link.to)] = link
	end

	for key, saved in before.links do
		local current = currentLinks[key]

		if current == nil or not sameValue(current, saved.link) then
			table.insert(restore.links, { index = saved.index, link = copyValue(saved.link) })
		end
	end

	for key, link in currentLinks do
		if before.links[key] == nil then
			table.insert(restore.removedLinks, { from = link.from, to = link.to })
		end
	end

	table.sort(restore.nodes, function(a: { index: number }, b: { index: number }): boolean
		return a.index < b.index
	end)
	table.sort(restore.links, function(a: { index: number }, b: { index: number }): boolean
		return a.index < b.index
	end)

	return restore
end

return diffDocs
