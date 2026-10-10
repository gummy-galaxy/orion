local githubTypes = require("@root/github/types")

type PullState = githubTypes.PullState

local function isRequestedFrom(pull: PullState, viewer: string): boolean
	for _, login in pull.requestedReviewers do
		if login:lower() == viewer:lower() then
			return true
		end
	end

	return false
end

return isRequestedFrom
