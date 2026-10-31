local createId = require("@root/common/createId")
local findItem = require("@root/canvas/items/findItem")
local getItem = require("@root/canvas/items/getItem")
local getNextSlot = require("@root/canvas/placement/getNextSlot")
local getStored = require("@root/canvas/suggestions/getStored")
local json = require("@std/json")
local moveItem = require("@root/canvas/placement/moveItem")
local save = require("@root/canvas/suggestions/save")
local suggestTypes = require("@root/canvas/suggestions/types")
local types = require("@root/types")

type Doc = types.Doc
type Group = suggestTypes.Group
type Item = types.Item

local function change(doc: Doc, action: string, ids: { string }, isAll: boolean): { string }
	local result = getStored(doc)
	assert(isAll or #ids > 0, "give suggestion ids or --all")
	local selected: { [string]: boolean } = {}
	local available: { [string]: boolean } = {}

	for _, group in result.groups do
		available[group.id] = true
	end

	for _, id in ids do
		assert(available[id], `no suggestion with id "{id}"`)
		selected[id] = true
	end

	local changed: { string } = {}
	local remaining: { Group } = {}
	local left: { [string]: boolean } = {}

	for _, group in result.groups do
		if isAll or selected[group.id] then
			if action == "apply" then
				for _, id in group.members do
					assert(findItem(doc, id), `no item with id "{id}"`)
				end

				local position = getNextSlot(doc, nil)
				local made: Item = {
					id = createId(),
					type = "cluster",
					position = position,
					width = 280,
					height = 110 + #group.members * 96,
					data = json.object({ kind = "cluster", label = group.title, layout = "pending" }),
				}
				table.insert(doc.nodes, made)

				for index, id in group.members do
					local from = getItem(doc, id).parentId

					if from then
						left[from] = true
					end

					moveItem(doc, id, made.id)
					getItem(doc, id).position = { x = 32, y = 78 + (index - 1) * 96 }
				end
			end

			table.insert(changed, group.id)
		else
			table.insert(remaining, group)
		end
	end

	-- Groups that lost cards keep their old gaps until the app tidies them.
	for id in left do
		local group = findItem(doc, id)

		if group and group.data.layout == nil then
			group.data.layout = "refit"
		end
	end

	result.groups = remaining
	save(doc, result)
	return changed
end

return change
