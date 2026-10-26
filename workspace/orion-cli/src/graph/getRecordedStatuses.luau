local getStringField = require("@root/getStringField")
local types = require("@root/types")

type Doc = types.Doc

-- The recorded status of every card, read before a write so markCelebrations
-- can see what changed.
local function getRecordedStatuses(doc: Doc): { [string]: string }
	local statuses: { [string]: string } = {}

	for _, item in doc.nodes do
		if item.type == "task" then
			statuses[item.id] = getStringField(item.data.status) or "todo"
		end
	end

	return statuses
end

return getRecordedStatuses
