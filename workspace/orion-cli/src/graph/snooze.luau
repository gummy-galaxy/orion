local getItem = require("@root/graph/getItem")
local isGroup = require("@root/graph/isGroup")
local isWork = require("@root/graph/isWork")
local types = require("@root/types")

type Doc = types.Doc

-- Hides a work item until `untilTime`, a UTC time in the form Orion stores, or
-- shows it again when nil.
local function snooze(doc: Doc, id: string, untilTime: string?)
	local item = getItem(doc, id)
	assert(not isGroup(item), `"{id}" is a group; snooze works on items`)
	assert(isWork(item), `"{id}" isn't work; snooze works on work items`)

	if untilTime then
		item.data.snoozedUntil = untilTime
	else
		item.data.snoozedUntil = nil
	end
end

return snooze
