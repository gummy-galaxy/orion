local findRef = require("@root/refs/findRef")
local githubTypes = require("@root/github/types")
local types = require("@root/types")

type Ref = githubTypes.Ref
type Item = types.Item

local function getRefFor(item: Item): Ref?
	local ref = findRef(item, "pull")

	if not ref then
		return nil
	end

	local host, owner, name, number = ref.key:match("^([^/]+)/([^/]+)/([^/]+)#(%d+)$")

	if not owner then
		owner, name, number = ref.key:match("^([^/]+)/([^/]+)#(%d+)$")
	end

	if not owner or not name or not number then
		return nil
	end

	return {
		owner = owner,
		name = assert(name),
		number = tonumber(number) :: number,
		host = host,
	}
end

return getRefFor
