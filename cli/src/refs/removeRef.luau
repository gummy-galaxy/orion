local getRefs = require("@root/refs/getRefs")
local types = require("@root/types")

type Item = types.Item

local function removeRef(item: Item, kind: string, key: string?)
	local refs = getRefs(item)

	for index = #refs, 1, -1 do
		local ref = refs[index]

		if ref.kind == kind and (key == nil or ref.key:lower() == key:lower()) then
			table.remove(refs, index)
		end
	end

	item.data.refs = if #refs > 0 then refs :: any else nil
end

return removeRef
