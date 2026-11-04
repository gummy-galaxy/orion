local findState = require("@root/canvas/cardTypes/findState")
local getDesired = require("@root/sources/github/pulls/getDesired")
local getStateMeaning = require("@root/canvas/cardTypes/getStateMeaning")
local getString = require("@root/sources/github/getString")
local githubTypes = require("@root/sources/github/types")
local types = require("@root/types")

type PullState = githubTypes.PullState
type Item = types.Item

-- Moves a card's state and whose move it is to match its pull request. The
-- pull request decides a meaning, such as done when it merges, and the card
-- records the state its own type declares for it. If the type declares states
-- but none with that meaning, the card keeps the state it has. A deferral that
-- a refresh set when the pull request closed isn't a hold, so the card follows
-- the pull request again.
local function setDesired(item: Item, pull: PullState, viewer: string)
	local meaning, who = getStateMeaning(item), getString(item.data.who)
	local held = if item.data.deferredByClosedPull == true then "todo" else meaning
	local nextMeaning, nextWho = getDesired(pull, held, who, viewer)

	item.data.who = nextWho

	if nextMeaning ~= meaning then
		local recorded = item.data.status
		item.data.status = findState(item, nextMeaning)

		-- For a meaning no state declares, findState gives back the meaning's
		-- own name, which a type with states would read as to do.
		if getStateMeaning(item) ~= nextMeaning then
			item.data.status = recorded
		end
	end

	if getStateMeaning(item) ~= "deferred" then
		item.data.deferredByClosedPull = nil
	elseif meaning ~= "deferred" then
		item.data.deferredByClosedPull = true
	end
end

return setDesired
