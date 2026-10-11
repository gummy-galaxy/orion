--[[
	Watches a pull request's latest CI run for its head commit until the perf job is running or finished, was skipped, or
	never queued, and stops after an hour. Polls every 30 seconds. A poll that fails is retried on the next one, so a
	flaky GitHub response doesn't end the watch early.
]]
local process = require("@std/process")
local task = require("@std/task")
local time = require("@std/time")

local getWatchDecision = require("@root/prioritize/getWatchDecision")
local parseJobs = require("@root/prioritize/parseJobs")
local parseLatestRun = require("@root/prioritize/parseLatestRun")
local runGh = require("@root/prioritize/runGh")
local types = require("@root/prioritize/types")

type WatchDecision = types.WatchDecision

local WATCH_SECONDS = 60 * 60
local POLL_SECONDS = 30

local env = process.env
local repository = assert(env.GITHUB_REPOSITORY, "GITHUB_REPOSITORY is not set")
local pullRequest = assert(env.PR, "PR is not set")

local headSha = string.match(runGh({ "api", `repos/{repository}/pulls/{pullRequest}`, "--jq", ".head.sha" }), "%x+")
assert(headSha, `could not read the head commit of PR #{pullRequest}`)

-- Reads the head commit's latest CI run and its jobs, then decides whether to keep watching.
local function poll(): WatchDecision
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

local started = time.now()

while true do
	local decision: WatchDecision = { stop = false, reason = "waiting" }
	local polled, result = pcall(poll)

	if polled then
		decision = result
	else
		print(`::warning::Poll failed, trying again: {result}`)
	end

	print(`Watching PR #{pullRequest} at {headSha}: {decision.reason}`)

	if decision.stop then
		break
	end

	if time.since(started) >= WATCH_SECONDS then
		print(`::warning::Stopped watching PR #{pullRequest} after an hour, and its perf job has not started`)
		break
	end

	task.wait(POLL_SECONDS)
end
