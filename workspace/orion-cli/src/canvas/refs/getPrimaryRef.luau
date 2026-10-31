local getRefs = require("@root/canvas/refs/getRefs")
local types = require("@root/types")

type Item = types.Item
type Ref = types.Ref

local function getPrimaryRef(item: Item): Ref?
	local refs = getRefs(item)

	for _, ref in refs do
		if ref.url then
			return ref
		end
	end

	return refs[1]
end

return getPrimaryRef
