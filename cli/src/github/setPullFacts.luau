local json = require("@std/json")

local getString = require("@root/github/getString")
local types = require("@root/types")

type Ref = types.Ref

local REVIEW_LABEL = {
	APPROVED = "Approved",
	CHANGES_REQUESTED = "Changes requested",
	REVIEW_REQUIRED = "Awaiting review",
}

local CHECK_STATE = {
	SUCCESS = "passing",
	FAILURE = "failing",
	ERROR = "failing",
	PENDING = "pending",
	EXPECTED = "pending",
}

local function getNumber(value: json.Value): number?
	return if type(value) == "number" then value else nil
end

local function getBoolean(value: json.Value): boolean?
	return if type(value) == "boolean" then value else nil
end

local function getStateLabel(details: json.Object): string?
	local state = getString(details.state)

	if not state then
		return nil
	end

	if state ~= "OPEN" then
		return `{state:sub(1, 1)}{state:sub(2):lower()} on GitHub`
	end

	local label = if details.draft == true
		then "Draft"
		else REVIEW_LABEL[getString(details.reviewDecision) or ""] or "Open"

	return `{label} on GitHub`
end

-- What stops an open pull request from merging, from a conflict to nothing at all.
local function getReadiness(details: json.Object): string?
	if details.state ~= "OPEN" then
		return nil
	end

	if details.mergeable == "CONFLICTING" or details.mergeState == "DIRTY" then
		return "conflict"
	end

	if details.checks == "FAILURE" or details.checks == "ERROR" then
		return "failing"
	end

	if details.checks == "PENDING" or details.checks == "EXPECTED" then
		return if details.checkProgress == "waiting" then "waiting" else "running"
	end

	if details.draft ~= true and (details.mergeState == "CLEAN" or details.mergeState == "HAS_HOOKS") then
		return "mergeable"
	end

	return if details.checks == "SUCCESS" then "passing" else nil
end

-- The jobs that failed, by name, and whether each one is optional, so it doesn't count toward the checks failing.
local function getFailures(details: json.Object): json.Array?
	local recorded = json.asArray(details.failedChecks)

	if not recorded then
		return nil
	end

	local failures: json.Array = {}

	for _, raw in recorded do
		local check = json.asObject(raw)
		local name = check and getString(check.name)

		if check and name then
			local failure = json.object({ name = name })
			failure.optional = if check.optional == true then true else nil
			table.insert(failures, failure)
		end
	end

	return failures
end

-- Check counts, progress, and failed jobs describe checks still to come or still to fix, so they only matter while
-- the pull request is open.
local function getChecks(details: json.Object): json.Object?
	local state = CHECK_STATE[getString(details.checks) or ""]

	if not state then
		return nil
	end

	local checks = json.object({ state = state })

	if details.state ~= "OPEN" then
		return checks
	end

	checks.progress = getString(details.checkProgress)
	local counts = json.asObject(details.checkCounts)

	if counts then
		checks.total = getNumber(counts.total)
		checks.finished = getNumber(counts.finished)
		checks.failed = getNumber(counts.failed)
	end

	checks.failures = getFailures(details)

	return checks
end

-- Sets the source-neutral facts the app shows from a pull request's recorded GitHub details. Facts the details no
-- longer support are cleared, so a merged pull request stops reading as ready to merge.
local function setPullFacts(ref: Ref, details: json.Object)
	ref.checkedAt = getString(details.checkedAt)
	ref.stateLabel = getStateLabel(details)
	ref.readiness = getReadiness(details)
	ref.checks = getChecks(details)
	ref.changesRequested = if details.reviewDecision == "CHANGES_REQUESTED" then true else nil
	ref.author = getString(details.author)
	ref.isMine = getBoolean(details.mine)
	ref.isReviewRequested = getBoolean(details.requestedFromYou)
	ref.additions = getNumber(details.additions)
	ref.deletions = getNumber(details.deletions)
	ref.head = getString(details.head)
end

return setPullFacts
