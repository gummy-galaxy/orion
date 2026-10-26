local types = require("@root/types")

type Doc = types.Doc

-- Refuses to reconnect around an item unless it has at most one incoming and
-- one outgoing link.
local function checkReconnect(doc: Doc, id: string)
	local incoming, outgoing = 0, 0

	for _, link in doc.links do
		if link.to == id then
			incoming += 1
		elseif link.from == id then
			outgoing += 1
		end
	end

	assert(incoming <= 1 and outgoing <= 1, `"{id}" needs at most one incoming and one outgoing link to reconnect`)
end

return checkReconnect
