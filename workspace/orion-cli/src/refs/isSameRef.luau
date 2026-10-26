local types = require("@root/types")

type Ref = types.Ref

--[[
	Whether two refs name the same work. Refs of one kind match by their
	sources' stable ids when both have one, since a key changes when what it
	names moves. Otherwise they match by case-insensitive key.
]]
local function isSameRef(a: Ref, b: Ref): boolean
	if a.kind ~= b.kind then
		return false
	end

	if a.id and b.id then
		return a.id == b.id
	end

	return a.key:lower() == b.key:lower()
end

return isSameRef
