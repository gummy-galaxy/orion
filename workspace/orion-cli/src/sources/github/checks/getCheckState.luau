local getCheckCounts = require("@root/sources/github/checks/getCheckCounts")
local getString = require("@root/sources/github/getString")
local json = require("@std/json")

-- A commit's checks as FAILURE, PENDING, or SUCCESS. Cancelled, skipped,
-- neutral, and stale checks don't fail it.
local function getCheckState(rollup: json.Object): string?
	local counts = getCheckCounts(rollup)

	if not counts then
		return getString(rollup.state)
	elseif counts.failed > 0 then
		return "FAILURE"
	elseif counts.finished < counts.total then
		return "PENDING"
	end

	return "SUCCESS"
end

return getCheckState
