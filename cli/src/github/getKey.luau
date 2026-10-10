local getGithubKey = require("@root/refs/getGithubKey")
local githubTypes = require("@root/github/types")

type Ref = githubTypes.Ref

local function getKey(ref: Ref): string
	return getGithubKey(ref.owner, ref.name, `#{ref.number}`, ref.host):lower()
end

return getKey
