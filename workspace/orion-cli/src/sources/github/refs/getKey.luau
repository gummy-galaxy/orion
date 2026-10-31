local getGithubKey = require("@root/sources/github/refs/getGithubKey")
local githubTypes = require("@root/sources/github/types")

type Ref = githubTypes.Ref

local function getKey(ref: Ref): string
	return getGithubKey(ref.owner, ref.name, `#{ref.number}`, ref.host):lower()
end

return getKey
