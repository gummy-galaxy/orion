local getString = require("@root/github/getString")
local json = require("@std/json")

type Counts = { failed: number, unfinished: number, total: number }

-- GitHub's own rollup state turns FAILURE when a job is cancelled, such as one a newer run replaced, even
-- while the rest still run. Only these conclusions mean a check failed.
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

local function addCounts(raw: json.Value, kindByState: { [string]: string }, counts: Counts)
	for _, value in json.asArray(raw) or {} do
		local entry = json.asObject(value)
		local state = if entry then getString(entry.state) else nil
		local count = if entry and type(entry.count) == "number" then entry.count else 0
		local kind = if state then kindByState[state] else nil

		counts.total += count

		if kind == "failed" then
			counts.failed += count
		elseif kind == "unfinished" then
			counts.unfinished += count
		end
	end
end

-- A commit's checks as FAILURE, PENDING, or SUCCESS. Cancelled, skipped, neutral, and stale checks don't fail it.
local function getCheckState(rollup: json.Object): string?
	local contexts = json.asObject(rollup.contexts)
	local fallback = getString(rollup.state)

	if not contexts then
		return fallback
	end

	local counts: Counts = { failed = 0, unfinished = 0, total = 0 }
	addCounts(contexts.checkRunCountsByState, CHECK_RUN_STATES, counts)
	addCounts(contexts.statusContextCountsByState, STATUS_CONTEXT_STATES, counts)

	if counts.total == 0 then
		return fallback
	elseif counts.failed > 0 then
		return "FAILURE"
	elseif counts.unfinished > 0 then
		return "PENDING"
	end

	return "SUCCESS"
end

return getCheckState
