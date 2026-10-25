local getKey = require("@root/github/getKey")
local getRefFor = require("@root/github/getRefFor")
local githubTypes = require("@root/github/types")
local types = require("@root/types")

type CheckSnooze = types.CheckSnooze
type Doc = types.Doc
type Fetched = githubTypes.Fetched
type PullState = githubTypes.PullState

local function hasPassed(pull: PullState, name: string): boolean
	if pull.passedChecks then
		return table.find(pull.passedChecks, name) ~= nil
	end

	-- Jobs are listed only when one failed, so a pull request whose checks all passed passed this one too.
	return pull.checks == "SUCCESS"
end

local function isFailing(pull: PullState, name: string): boolean
	for _, check in pull.failedChecks or {} do
		if check.name == name and not check.optional then
			return true
		end
	end

	return false
end

-- Brings check snoozes up to date after a refresh. A timed snooze ends once its time passes. A snooze that lasts until
-- the job passes records each card it has since passed on, so a later failure there shows again, and it ends once no
-- open card is still hiding a failure of that job.
local function trackCheckSnoozes(doc: Doc, fetched: Fetched, now: string)
	local snoozes = doc.settings.checkSnoozes

	for index = #snoozes, 1, -1 do
		local snooze = snoozes[index]

		if snooze.untilTime then
			if snooze.untilTime <= now then
				table.remove(snoozes, index)
			end

			continue
		end

		local repo = snooze.repo:lower()
		local hiding = false

		for _, item in doc.nodes do
			local ref = getRefFor(item)
			local pull = if ref and string.lower(`{ref.owner}/{ref.name}`) == repo
				then fetched.pulls[getKey(ref)]
				else nil

			if pull and pull.state == "OPEN" then
				local alreadyPassed = table.find(snooze.passed, item.id) ~= nil

				if not alreadyPassed and hasPassed(pull, snooze.name) then
					table.insert(snooze.passed, item.id)
					alreadyPassed = true
				end

				hiding = hiding or (not alreadyPassed and isFailing(pull, snooze.name))
			end
		end

		-- A refresh that couldn't fetch every card can't tell whether a job still fails anywhere, so it keeps the snooze.
		if not hiding and #fetched.failures == 0 then
			table.remove(snoozes, index)
		end
	end
end

return trackCheckSnoozes
