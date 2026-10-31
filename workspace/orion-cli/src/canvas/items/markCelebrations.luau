local getStateMeaning = require("@root/canvas/cardTypes/getStateMeaning")
local isNote = require("@root/canvas/items/isNote")
local types = require("@root/types")

type Doc = types.Doc

-- Sets `celebrate` on a card that changed to done, so it waits to be closed
-- out, and clears it when the card is reopened. Cards created done and notes
-- never get the flag, and cards finished before the flag existed don't have it.
-- The app sends `celebrate = false` for a card it finished and closed out at
-- once, so that card doesn't wait.
local function markCelebrations(doc: Doc, previous: { [string]: string })
	for _, item in doc.nodes do
		if item.type == "task" and not isNote(item) then
			local status = getStateMeaning(item)
			local wasOpen = previous[item.id] ~= nil and previous[item.id] ~= "done"

			if item.data.celebrate == false or status ~= "done" then
				item.data.celebrate = nil
			elseif wasOpen then
				item.data.celebrate = true
			end
		end
	end
end

return markCelebrations
