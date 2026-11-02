local json = require("@std/json")

local getString = require("@root/sources/github/getString")
local githubTypes = require("@root/sources/github/types")

type CheckCounts = githubTypes.CheckCounts

-- GitHub's own rollup state turns FAILURE when a job is cancelled, such as one
-- a newer run replaced, even while the rest still run. Only these conclusions
-- mean a check failed.
local CHECK_RUN_STATES: { [string]: string } = {
	FAILURE = "failed",
	TIMED_OUT = "failed",
	STARTUP_FAILURE = "failed",
	ACTION_REQUIRED = "failed",
	IN_PROGRESS = "unfinished",
	QUEUED = "unfinished",
	PENDING = "unfinished",
	WAITING = "unfinished",
	REQUESTED = "unfinished",
}
local STATUS_CONTEXT_STATES: { [string]: string } = {
	FAILURE = "failed",
	ERROR = "failed",
	PENDING = "unfinished",
	EXPECTED = "unfinished",
}

local function addCounts(raw: json.Value, kindByState: { [string]: string }, counts: CheckCounts)
	for _, value in json.asArray(raw) or {} do
		local entry = json.asObject(value)
		local state = if entry then getString(entry.state) else nil
		local count = if entry and type(entry.count) == "number" then entry.count else 0
		local kind = if state then kindByState[state] else nil

		counts.total += count

		if kind == "failed" then
			counts.failed += count
		end

		if kind ~= "unfinished" then
			counts.finished += count
		end
	end
end

-- How many of a commit's checks have finished and failed, out of all of them.
-- Cancelled, skipped, neutral, and stale checks count as finished without
-- failing. Absent when the rollup has no per-state counts or no checks.
local function getCheckCounts(rollup: json.Object): CheckCounts?
	local contexts = json.asObject(rollup.contexts)

	if not contexts then
		return nil
	end

	local counts: CheckCounts = { total = 0, finished = 0, failed = 0 }
	addCounts(contexts.checkRunCountsByState, CHECK_RUN_STATES, counts)
	addCounts(contexts.statusContextCountsByState, STATUS_CONTEXT_STATES, counts)

	if counts.total == 0 then
		return nil
	end

	return counts
end

return getCheckCounts
