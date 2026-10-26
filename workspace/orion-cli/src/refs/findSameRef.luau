local getRefs = require("@root/refs/getRefs")
local isSameRef = require("@root/refs/isSameRef")
local types = require("@root/types")

type Item = types.Item
type Ref = types.Ref

-- The ref on `item` that names the same work as `ref`, by `isSameRef`.
local function findSameRef(item: Item, ref: Ref): Ref?
	for _, existing in getRefs(item) do
		if isSameRef(existing, ref) then
			return existing
		end
	end

	return nil
end

return findSameRef
