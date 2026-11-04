local json = require("@std/json")

local getString = require("@root/sources/github/getString")

type Progress = { running: number, waiting: number }

-- Check runs report whether they started. A pending commit status could be
-- either, so it counts as running.
local CHECK_RUN_PROGRESS: { [string]: string } = {
	IN_PROGRESS = "running",
	QUEUED = "waiting",
	PENDING = "waiting",
	WAITING = "waiting",
	REQUESTED = "waiting",
}
local STATUS_CONTEXT_PROGRESS: { [string]: string } = { PENDING = "running", EXPECTED = "waiting" }

local function addCounts(counts: json.Value, progressByState: { [string]: string }, progress: Progress)
	for _, raw in json.asArray(counts) or {} do
		local entry = json.asObject(raw)
		local state = if entry then getString(entry.state) else nil
		local kind = if state then progressByState[state] else nil

		if entry and kind and type(entry.count) == "number" then
			if kind == "running" then
				progress.running += entry.count
			else
				progress.waiting += entry.count
			end
		end
	end
end

-- Whether a commit's unfinished checks have started: "running" if any has,
-- "waiting" if all are queued.
local function getCheckProgress(rollup: json.Object): string?
	local contexts = json.asObject(rollup.contexts)

	if not contexts then
		return nil
	end

	local progress: Progress = { running = 0, waiting = 0 }
	addCounts(contexts.checkRunCountsByState, CHECK_RUN_PROGRESS, progress)
	addCounts(contexts.statusContextCountsByState, STATUS_CONTEXT_PROGRESS, progress)

	if progress.running > 0 then
		return "running"
	elseif progress.waiting > 0 then
		return "waiting"
	end

	return nil
end

return getCheckProgress
