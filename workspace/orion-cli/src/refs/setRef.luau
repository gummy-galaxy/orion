local json = require("@std/json")

local getRefs = require("@root/refs/getRefs")
local isSameRef = require("@root/refs/isSameRef")
local types = require("@root/types")

type Item = types.Item
type Ref = types.Ref

local function setRef(item: Item, ref: Ref): Ref
	local refs = getRefs(item)
	local recorded: Ref = ref
	local found = false

	for index, existing in refs do
		if isSameRef(existing, ref) then
			local merged = json.object(existing :: any)

			for field, value in ref :: any do
				merged[field] = value
			end

			recorded = merged :: any
			refs[index] = recorded
			found = true
			break
		end
	end

	if not found then
		recorded = json.object(ref :: any) :: any
		if ref.kind == "pull" then
			table.insert(refs, 1, recorded)
		else
			table.insert(refs, recorded)
		end
	end

	item.data.refs = refs :: any
	return recorded
end

return setRef
