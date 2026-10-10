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
		components = progress.components,
	})
	object.parent = item.parentId
	object.color = item.data.color
	return object
end

function group.formatLine(doc: Doc, derived: graph.Derived, item: Item): string
	local progress = graph.countProgress(doc, derived, item.id)
	local parts = {}

	if progress.total > 0 or progress.components == 0 then
		table.insert(parts, `{progress.done}/{progress.total} done, {progress.ready} ready`)
	end

	if progress.components > 0 then
		table.insert(parts, `{progress.components} {if progress.components == 1 then "component" else "components"}`)
	end

	return `{graph.label(item)}  {table.concat(parts, ", ")}`
end

return table.freeze(group)
