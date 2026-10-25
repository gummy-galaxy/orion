local findItem = require("@root/graph/findItem")
local getContents = require("@root/graph/getContents")
local getGroup = require("@root/graph/getGroup")
local isGroup = require("@root/graph/isGroup")
local pruneEmptied = require("@root/graph/pruneEmptied")
local removeItem = require("@root/graph/removeItem")
local types = require("@root/types")

type Doc = types.Doc

-- Removes a group with everything inside it. Each card goes the way `removeItem` takes it, so a note's links
-- reconnect around it, and a parent left empty disappears.
local function removeGroup(doc: Doc, id: string)
	local parentId = getGroup(doc, id).parentId
	local groupIds = { [id] = true }

	for _, item in getContents(doc, id) do
		if isGroup(item) then
			groupIds[item.id] = true
		elseif findItem(doc, item.id) then
			removeItem(doc, item.id)
		end
	end

	for index = #doc.nodes, 1, -1 do
		if groupIds[doc.nodes[index].id] then
			table.remove(doc.nodes, index)
		end
	end

	pruneEmptied(doc, parentId)
end

return removeGroup
