local json = require("@std/json")

local checkFields = require("@root/graph/checkFields")
local chooseItemKind = require("@root/graph/chooseItemKind")
local createId = require("@root/graph/createId")
local getGroup = require("@root/graph/getGroup")
local getNextSlot = require("@root/graph/getNextSlot")
local graphTypes = require("@root/graph/types")
local setLook = require("@root/graph/setLook")
local types = require("@root/types")

type AddOptions = graphTypes.AddOptions
type Doc = types.Doc
type Item = types.Item

local function addItem(doc: Doc, label: string, options: AddOptions): Item
	assert(label ~= "", "an item needs a label")
	checkFields(options)
	assert(options.shape == nil or options.kind == nil or options.kind == "component", "only components take a shape")

	if options.group then
		getGroup(doc, options.group)
	end

	local data: json.Object = json.object({
		kind = "task",
		label = label,
		-- A shape only fits a component, so giving one makes the item a component.
		itemKind = chooseItemKind(options.repo, nil, if options.shape then "component" else options.kind),
		status = options.status or "todo",
	})
	data.repo = options.repo
	data.note = options.note
	data.who = if options.who == "" then nil else options.who
	local item: Item = {
		id = createId(),
		type = "task",
		position = getNextSlot(doc, options.group),
		parentId = options.group,
		data = data,
	}

	setLook(item, options)
	table.insert(doc.nodes, item)
	return item
end

return addItem
