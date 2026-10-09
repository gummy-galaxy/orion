local githubTypes = require("@root/github/types")
local types = require("@root/types")

type Ref = githubTypes.Ref
type Item = types.Item

local function getRefFor(item: Item, defaultOwner: string): Ref?
	local repo = item.data.repo
	local number = item.data.pr

	if type(repo) ~= "string" or type(number) ~= "number" then
		return nil
	end

	local owner, name = repo:match("^([^/]+)/([^/]+)$")
	return {
		owner = owner or defaultOwner,
		name = name or repo,
		number = number,
		host = if type(item.data.host) == "string" then item.data.host else nil,
	}
end

return getRefFor
