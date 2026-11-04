local cardTypes = require("@root/canvas/cardTypes/types")
local githubTypes = require("@root/sources/github/types")
local isRequestedFrom = require("@root/sources/github/pulls/isRequestedFrom")

type PullState = githubTypes.PullState
type StateMeaning = cardTypes.StateMeaning

local function getDesired(pull: PullState, status: StateMeaning, who: string?, viewer: string): (StateMeaning, string?)
	if pull.state == "MERGED" then
		return "done", nil
	elseif pull.state == "CLOSED" then
		return if status == "done" then "done" else "deferred", nil
	elseif status == "blocked" or status == "deferred" then
		return status :: StateMeaning, who
	elseif pull.author:lower() ~= viewer:lower() then
		return "review", if isRequestedFrom(pull, viewer) then "you" else nil
	elseif pull.draft or pull.reviewDecision == "CHANGES_REQUESTED" then
		return "active", "you"
	elseif pull.reviewDecision == "APPROVED" then
		return "review", "you"
	elseif pull.reviewRequests > 0 then
		return "review", "review"
	end

	return "review", "you"
end

return getDesired
