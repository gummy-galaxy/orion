local perfComment = require("@root/perf/perfComment")

-- Reports whether a perf comment shows a finished comparison of `sha`. A failed comparison doesn't count, so its
-- commit gets measured again.
local function isMeasured(body: string, sha: string): boolean
	if sha == "" or string.find(body, perfComment.FAILURE, 1, true) then
		return false
	end

	-- The footer names the commit by its first seven characters.
	local short = string.sub(sha, 1, 7)

	return string.find(body, `Measured {short} on`, 1, true) ~= nil
end

return isMeasured
