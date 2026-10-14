local githubTypes = require("@root/github/types")

type CheckRun = githubTypes.CheckRun
type FailedCheck = githubTypes.FailedCheck
type PullState = githubTypes.PullState

-- Records which jobs failed and passed on a pull request. When some jobs are required, a failed job that isn't
-- leaves the pull request's state alone: its failure count drops it, and checks no longer read as failing for it.
local function applyCheckRuns(pull: PullState, runs: { CheckRun })
	local hasRequired = false

	for _, run in runs do
		hasRequired = hasRequired or run.required
	end

	local failedChecks: { FailedCheck } = {}
	local passedChecks: { string } = {}
	local optionalFailures = 0

	for _, run in runs do
		if run.state == "failed" then
			local optional = hasRequired and not run.required
			table.insert(failedChecks, { name = run.name, optional = optional })

			if optional then
				optionalFailures += 1
			end
		elseif run.state == "passed" then
			table.insert(passedChecks, run.name)
		end
	end

	pull.failedChecks = failedChecks
	pull.passedChecks = passedChecks

	local counts = pull.checkCounts

	if counts and optionalFailures > 0 then
		counts.failed = math.max(0, counts.failed - optionalFailures)

		if counts.failed > 0 then
			pull.checks = "FAILURE"
		elseif counts.finished < counts.total then
			pull.checks = "PENDING"
		else
			pull.checks = "SUCCESS"
		end
	end
end

return applyCheckRuns
