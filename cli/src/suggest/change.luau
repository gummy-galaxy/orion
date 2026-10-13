local getStored = require("@root/suggest/getStored")
local graph = require("@root/graph")
local json = require("@std/json")
local save = require("@root/suggest/save")
local suggestTypes = require("@root/suggest/types")
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
					assert(graph.find(doc, id), `no item with id "{id}"`)
				end

				local position = graph.nextSlot(doc, nil)
				local made: Item = {
					id = group.id,
					type = "cluster",
					position = position,
					width = 280,
					height = 110 + #group.members * 96,
					data = json.object({ kind = "cluster", label = group.title, layout = "pending" }),
				}
				local base = group.title:lower():gsub("[^%w]+", "-"):gsub("^%-+", ""):gsub("%-+$", "")

				if base == "" then
					base = "group"
				end

				made.id = base:sub(1, 32)
				local suffix = 2

				while graph.find(doc, made.id) do
					made.id = `{base:sub(1, 32)}-{suffix}`
					suffix += 1
				end

				table.insert(doc.nodes, made)

				for index, id in group.members do
					local from = graph.get(doc, id).parentId

					if from then
						left[from] = true
					end

					graph.move(doc, id, made.id)
					graph.get(doc, id).position = { x = 32, y = 78 + (index - 1) * 96 }
				end
			end

			table.insert(changed, group.id)
		else
			table.insert(remaining, group)
		end
	end

	-- Groups that lost cards keep their old gaps until the app tidies them.
	for id in left do
		local group = graph.find(doc, id)

		if group and group.data.layout == nil then
			group.data.layout = "refit"
		end
	end

	result.groups = remaining
	save(doc, result)
	return changed
end

return change
