local findItem = require("@root/canvas/items/findItem")
local raiseFailure = require("@root/common/errors/raiseFailure")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item

local function getItem(doc: Doc, id: string): Item
	local item = findItem(doc, id)

	if not item then
		raiseFailure("missing-item", `no item or group with id "{id}"`)
	end

	return item :: Item
end

return getItem
