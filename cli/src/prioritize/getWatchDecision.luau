local types = require("@root/prioritize/types")

type Job = types.Job
type WatchDecision = types.WatchDecision

-- The perf job in ci.yml. It is the job the pinned runner exists for.
local PERF_JOB = "perf"

local function findPerfJob(jobs: { Job }): Job?
	for _, job in jobs do
		if job.name == PERF_JOB then
			return job
		end
	end

	return nil
end

-- Decides whether to keep watching a pull request's CI run. Watching stops once the perf job is running or finished,
-- once it was skipped, or once the run has finished without a perf job, such as when the changes filter skipped it.
local function getWatchDecision(jobs: { Job }, runCompleted: boolean): WatchDecision
	local perfJob = findPerfJob(jobs)

	if perfJob then
		if perfJob.status == "in_progress" then
			return { stop = true, reason = "perf job is running" }
		end

		if perfJob.status == "completed" then
			if perfJob.conclusion == "skipped" then
				return { stop = true, reason = "perf job was skipped" }
			end

			return { stop = true, reason = "perf job finished" }
		end

		return { stop = false, reason = "perf job is queued" }
	end

	if runCompleted then
		return { stop = true, reason = "CI finished without a perf job" }
	end

	return { stop = false, reason = "waiting for the perf job to queue" }
end

return getWatchDecision
