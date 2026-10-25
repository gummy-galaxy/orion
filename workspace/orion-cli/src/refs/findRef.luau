local getRefs = require("@root/refs/getRefs")
local types = require("@root/types")

type Item = types.Item
type Ref = types.Ref

local function findRef(item: Item, kind: string, key: string?): Ref?
	for _, ref in getRefs(item) do
		if ref.kind == kind and (key == nil or ref.key:lower() == key:lower()) then
			return ref
		end
	end

	return nil
end

return findRef
