local json = require("@std/json")

local graph = require("@root/graph")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item

local group = {}

function group.serialize(doc: Doc, derived: graph.Derived, item: Item): json.Object
	local progress = graph.countProgress(doc, derived, item.id)
	local object: json.Object = json.object({
		id = item.id,
		label = graph.label(item),
		total = progress.total,
		done = progress.done,
		ready = progress.ready,
	})
	object.parent = item.parentId
	return object
end

function group.formatLine(doc: Doc, derived: graph.Derived, item: Item): string
	local progress = graph.countProgress(doc, derived, item.id)
	return `{graph.label(item)}  {progress.done}/{progress.total} done, {progress.ready} ready`
end

return table.freeze(group)
