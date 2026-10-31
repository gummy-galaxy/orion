local json = require("@std/json")

local countProgress = require("@root/canvas/items/countProgress")
local getLabel = require("@root/canvas/items/getLabel")
local getStringField = require("@root/common/getStringField")
local graphTypes = require("@root/canvas/types")
local types = require("@root/types")

type Item = types.Item

local group = {}

-- The one JSON shape for a group, whichever command prints it.
function group.serialize(derived: graphTypes.Derived, item: Item): json.Object
	local progress = countProgress(derived, item.id)
	local object: json.Object = json.object({
		id = item.id,
		kind = "group",
		total = progress.total,
		done = progress.done,
		ready = progress.ready,
		components = progress.components,
		arrange = getStringField(item.data.arrange) or "auto",
	})
	object.label = getStringField(item.data.label)
	object.group = item.parentId
	object.color = item.data.color
	return object
end

function group.formatLine(derived: graphTypes.Derived, item: Item): string
	local progress = countProgress(derived, item.id)
	local parts = {}

	if progress.total > 0 or progress.components == 0 then
		table.insert(parts, `{progress.done}/{progress.total} done, {progress.ready} ready`)
	end

	if progress.components > 0 then
		table.insert(parts, `{progress.components} {if progress.components == 1 then "component" else "components"}`)
	end

	return `{getLabel(item)}  {table.concat(parts, ", ")}`
end

return table.freeze(group)
