local runGh = require("@lib/runGh")

-- Reads the head commit of a pull request.
local function getHeadSha(repository: string, pullRequest: string): string
	local sha = string.match(runGh({ "api", `repos/{repository}/pulls/{pullRequest}`, "--jq", ".head.sha" }), "%x+")

	assert(sha, `could not read the head commit of PR #{pullRequest}`)

	return sha
end

return getHeadSha
