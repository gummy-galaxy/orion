local githubTypes = require("@root/github/types")

type Ref = githubTypes.Ref

local function getKey(ref: Ref): string
	local host = if ref.host and ref.host ~= "github.com" then `{ref.host}/` else ""
	return string.lower(`{host}{ref.owner}/{ref.name}#{ref.number}`)
end

return getKey
