local getWatchDecision = require("@lib/getWatchDecision")
local parseJobs = require("@lib/parseJobs")
local parseLatestRun = require("@lib/parseLatestRun")
local runGh = require("@lib/runGh")
local types = require("@lib/types")

type WatchDecision = types.WatchDecision

-- Reads the head commit's latest CI run and that run's jobs from GitHub, then decides whether to keep watching.
local function fetchWatchDecision(repository: string, headSha: string): WatchDecision
	local run = parseLatestRun(runGh({
		"api",
		`repos/{repository}/actions/workflows/ci.yml/runs?head_sha={headSha}&event=pull_request&per_page=30`,
		"--jq",
		'[.workflow_runs[] | [.id, .status, (.conclusion // "")]] | sort_by(.[0]) | last // empty | @tsv',
	}))

	if not run then
		return getWatchDecision({}, false)
	end

	local jobs = parseJobs(runGh({
		"api",
		`repos/{repository}/actions/runs/{run.id}/jobs`,
		"--paginate",
		"--jq",
		'.jobs[] | [.name, .status, (.conclusion // "")] | @tsv',
	}))

	return getWatchDecision(jobs, run.status == "completed")
end

return fetchWatchDecision
