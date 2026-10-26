local json = require("@std/json")

local findRef = require("@root/refs/findRef")
local getRefFor = require("@root/github/getRefFor")
local getString = require("@root/github/getString")
local setPullFacts = require("@root/github/setPullFacts")
local types = require("@root/types")

type CheckSnooze = types.CheckSnooze
type Item = types.Item
type Ref = types.Ref
type SnoozedFacts = types.SnoozedFacts

-- The snooze covering a job on a card: one for the job in the card's repository
-- that hasn't ended, and that the job hasn't passed on the card since.
local function findSnooze(
	snoozes: { CheckSnooze },
	repo: string,
	name: string,
	cardId: string,
	clock: string
): CheckSnooze?
	for _, snooze in snoozes do
		local isRunning = snooze.untilTime == nil or snooze.untilTime > clock
		local hasPassed = snooze.untilTime == nil and table.find(snooze.passed, cardId) ~= nil

		if snooze.repo:lower() == repo and snooze.name == name and isRunning and not hasPassed then
			return snooze
		end
	end

	return nil
end

-- A card's pull request facts as if its snoozed jobs hadn't failed, or nil when
-- no snooze covers a job that failed there. The facts come from the recorded
-- details the same way a refresh reads them, so a card whose only failures are
-- snoozed reads as running, passing, or ready to merge. `clock` is the current
-- UTC time, so a timed snooze stops counting once it ends, before a refresh
-- clears it.
local function getSnoozedFacts(item: Item, snoozes: { CheckSnooze }, clock: string): SnoozedFacts?
	if #snoozes == 0 then
		return nil
	end

	local ref = findRef(item, "pull")
	local pull = getRefFor(item)
	local details = ref and ref.details

	if not ref or not pull or not details or details.state ~= "OPEN" then
		return nil
	end

	local repo = string.lower(`{pull.owner}/{pull.name}`)
	local snoozed: { { name: string, untilTime: string? } } = {}
	local counted = 0
	local wakesAt: string?

	for _, raw in json.asArray(details.failedChecks) or {} do
		local check = json.asObject(raw)
		local name = check and getString(check.name)

		if not check or not name or check.optional == true then
			continue
		end

		counted += 1
		local snooze = findSnooze(snoozes, repo, name, item.id, clock)

		if snooze then
			table.insert(snoozed, { name = name, untilTime = snooze.untilTime })

			if snooze.untilTime and (wakesAt == nil or snooze.untilTime < wakesAt) then
				wakesAt = snooze.untilTime
			end
		end
	end

	if #snoozed == 0 then
		return nil
	end

	local adjusted = table.clone(details)

	if details.checks == "FAILURE" or details.checks == "ERROR" then
		local counts = json.asObject(details.checkCounts)
		local recordedFailed = counts and counts.failed
		local failed = if type(recordedFailed) == "number"
			then math.max(0, recordedFailed - #snoozed)
			else counted - #snoozed

		if counts and type(recordedFailed) == "number" then
			local lowered = table.clone(counts)
			lowered.failed = failed
			adjusted.checkCounts = lowered
		end

		if failed == 0 then
			local total = counts and counts.total
			local finished = counts and counts.finished
			local isRunning = type(total) == "number" and type(finished) == "number" and finished < total
			adjusted.checks = if isRunning then "PENDING" else "SUCCESS"
		end
	end

	local facts: Ref = { source = ref.source, kind = ref.kind, key = ref.key }
	setPullFacts(facts, adjusted)

	return { readiness = facts.readiness, checks = facts.checks, snoozed = snoozed, wakesAt = wakesAt }
end

return getSnoozedFacts
