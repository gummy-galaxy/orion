local getGroup = require("@root/graph/getGroup")
local types = require("@root/types")

type Doc = types.Doc

-- Marks a group for the app to lay out in place, as `orion group tidy` does. A pending marker is kept, since the app already
-- places that group. A custom group is marked too; the app clears the marker and leaves its arrangement alone.
local function markForTidy(doc: Doc, id: string)
	local group = getGroup(doc, id)

	if group.data.layout == nil then
		group.data.layout = "refit"
	end
end

return markForTidy
