local getStateMeaning = require("@root/cardTypes/getStateMeaning")
local types = require("@root/types")

type Doc = types.Doc

-- What every card's recorded state counts as, read before a write so
-- markCelebrations can see what changed.
local function getRecordedStatuses(doc: Doc): { [string]: string }
	local statuses: { [string]: string } = {}

	for _, item in doc.nodes do
		if item.type == "task" then
			statuses[item.id] = getStateMeaning(item)
		end
	end

	return statuses
end

return getRecordedStatuses
