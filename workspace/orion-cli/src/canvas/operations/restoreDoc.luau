local copyValue = require("@root/canvas/operations/copyValue")
local operationTypes = require("@root/canvas/operations/types")
local setRawValue = require("@root/canvas/operations/setRawValue")
local types = require("@root/types")

type Doc = types.Doc
type Restore = operationTypes.Restore

local function indexOfNode(doc: Doc, id: string): number?
	for index, item in doc.nodes do
		if item.id == id then
			return index
		end
	end

	return nil
end

local function indexOfLink(doc: Doc, from: string, to: string): number?
	for index, link in doc.links do
		if link.from == from and link.to == to then
			return index
		end
	end

	return nil
end

-- Puts a change back as `diffDocs` recorded it. Links go first, so no link is
-- left pointing at a removed node. The restore is copied as it's applied, so
-- the same restore can be applied again.
local function restoreDoc(doc: Doc, restore: Restore)
	for _, removed in restore.removedLinks do
		local index = indexOfLink(doc, removed.from, removed.to)

		if index then
			table.remove(doc.links, index)
		end
	end

	for _, id in restore.removedNodes do
		local index = indexOfNode(doc, id)

		if index then
			table.remove(doc.nodes, index)
		end
	end

	for _, entry in restore.nodes do
		local item = copyValue(entry.item)
		local index = indexOfNode(doc, item.id)

		if index then
			doc.nodes[index] = item
		else
			table.insert(doc.nodes, math.min(entry.index, #doc.nodes + 1), item)
		end
	end

	for _, entry in restore.links do
		local link = copyValue(entry.link)
		local index = indexOfLink(doc, link.from, link.to)

		if index then
			doc.links[index] = link
		else
			table.insert(doc.links, math.min(entry.index, #doc.links + 1), link)
		end
	end

	if restore.stickers then
		setRawValue(doc, "stickers", restore.stickers.value)
	end

	if restore.stickerLoadout then
		setRawValue(doc, "stickerLoadout", restore.stickerLoadout.value)
	end
end

return restoreDoc
