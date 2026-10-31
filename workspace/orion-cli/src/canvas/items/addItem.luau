local json = require("@std/json")

local checkFields = require("@root/canvas/items/checkFields")
local chooseItemKind = require("@root/canvas/items/chooseItemKind")
local createId = require("@root/common/createId")
local findPlacement = require("@root/canvas/placement/findPlacement")
local getNeighborGroup = require("@root/canvas/groups/getNeighborGroup")
local graphTypes = require("@root/canvas/types")
local linkNeighbors = require("@root/canvas/links/linkNeighbors")
local setLook = require("@root/canvas/items/setLook")
local types = require("@root/types")

type AddOptions = graphTypes.AddOptions
type Doc = types.Doc
type Item = types.Item

-- Adds a work item beside the items it links to, after `after` and before
-- `before` when given.
local function addItem(doc: Doc, label: string, options: AddOptions): Item
	assert(label ~= "", "an item needs a label")
	checkFields(options)
	assert(options.shape == nil or options.kind == nil or options.kind == "component", "only components take a shape")

	local group = getNeighborGroup(doc, options.group, options.after, options.before)
	local data: json.Object = json.object({
		kind = "task",
		label = label,
		-- A shape only fits a component, so giving one makes the item a
		-- component.
		itemKind = chooseItemKind(options.repo, nil, if options.shape then "component" else options.kind),
		status = options.status or "todo",
	})
	data.repo = options.repo
	data.note = options.note
	data.who = if options.who == "" then nil else options.who
	local item: Item = {
		id = createId(),
		type = "task",
		position = { x = 0, y = 0 },
		parentId = group,
		data = data,
	}

	setLook(item, options)
	table.insert(doc.nodes, item)
	linkNeighbors(doc, item.id, options.after, options.before)
	item.position = findPlacement(doc, item)
	return item
end

return addItem
