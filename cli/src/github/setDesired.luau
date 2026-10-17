local getDesired = require("@root/github/getDesired")
local getString = require("@root/github/getString")
local githubTypes = require("@root/github/types")
local types = require("@root/types")

type PullState = githubTypes.PullState
type Item = types.Item

-- Moves a card's status and whose move it is to match its pull request.
-- A deferral that a refresh set when the pull request closed isn't a hold, so the card follows the pull request again.
local function setDesired(item: Item, pull: PullState, viewer: string)
	local status, who = getString(item.data.status) or "todo", getString(item.data.who)
	local held = if item.data.deferredByClosedPull == true then "todo" else status
	local nextStatus, nextWho = getDesired(pull, held, who, viewer)

	item.data.status, item.data.who = nextStatus, nextWho

	if nextStatus ~= "deferred" then
		item.data.deferredByClosedPull = nil
	elseif status ~= "deferred" then
		item.data.deferredByClosedPull = true
	end
end

return setDesired
