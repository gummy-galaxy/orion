local derive = require("@root/canvas/derive")
local getLabel = require("@root/canvas/items/getLabel")
local isGroup = require("@root/canvas/groups/isGroup")
local queryTypes = require("@root/canvas/query/types")
local types = require("@root/types")

type Item = types.Item
type Scope = queryTypes.Scope

-- Derives the graph and works out every group's path and parent once, so
-- matching and sorting a whole canvas reads each from a table.
local function createScope(doc: types.Doc, now: string?): Scope
	local byId: { [string]: Item } = {}
	local groupPaths: { [string]: { string } } = {}
	local groupParents: { [string]: string } = {}

	for _, item in doc.nodes do
		byId[item.id] = item
	end

	local function getPath(item: Item, visiting: { [string]: boolean }): { string }
		local known = groupPaths[item.id]

		if known then
			return known
		end

		local parent = if item.parentId then byId[item.parentId] else nil
		local path: { string } = {}

		-- A group nested in itself through a broken file stops the walk.
		if parent and not visiting[parent.id] then
			visiting[item.id] = true
			path = table.clone(getPath(parent, visiting))
		end

		table.insert(path, getLabel(item))
		groupPaths[item.id] = path
		return path
	end

	for _, item in doc.nodes do
		if isGroup(item) then
			getPath(item, {})
			groupParents[item.id] = item.parentId
		end
	end

	return { derived = derive(doc, now), groupPaths = groupPaths, groupParents = groupParents }
end

return createScope
