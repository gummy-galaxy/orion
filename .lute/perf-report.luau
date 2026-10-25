--[[
	Publishes the perf comparison in workspace/orion-app/.perf/report.md from CI's perf job. It adds the report to the job summary
	and, for a pull request, keeps it in one comment, replacing the comment an earlier run left. When the comparison
	fails, the comment says so and links the run. A push to main has no pull request, so its report stays in the summary.

	A fork's perf job has a read-only token, so it uploads its report and the Perf Report workflow publishes it. Setting
	RUN_ID publishes for that run: it downloads the report, takes the runner from the run's perf job, and finds the pull
	request from SHA and HEAD_REPOSITORY, since a fork's workflow_run event lists no pull requests.
]]
local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")

local command = require("@cli/command")
local runScript = require("@cli/runScript")
local upsertComment = require("@cli/github/upsertComment")

local MARKER = "<!-- orion-perf -->"

local env = process.env
local reportDir = path.resolve("workspace/orion-app/.perf")
local reportPath = path.join(reportDir, "report.md")
local repository = assert(env.GITHUB_REPOSITORY, "GITHUB_REPOSITORY is not set")

-- Returns the runner that ran the run's perf job, or nil when the job never started, such as when a maintainer
-- declined to run it.
local function findPerfRunner(runId: string): string?
	local listed = command({
		"gh",
		"api",
		`repos/{repository}/actions/runs/{runId}/jobs`,
		"--jq",
		'.jobs[] | select(.name == "perf" and (.steps | length) > 0) | .runner_name',
	}, nil)
	assert(listed.ok, listed.stderr)

	return string.match(listed.stdout, "[^\n]+")
end

local function findPullRequest(sha: string, headRepository: string): string?
	local listed = command({
		"gh",
		"api",
		`repos/{repository}/pulls`,
		"--paginate",
		"--jq",
		`.[] | select(.head.sha == "{sha}" and .head.repo.full_name == "{headRepository}") | .number`,
	}, nil)
	assert(listed.ok, listed.stderr)

	return string.match(listed.stdout, "%d+")
end

runScript(function()
	local pullRequest = env.PR
	local runner = env.RUNNER_NAME
	local runNumber = env.RUN_NUMBER or env.GITHUB_RUN_NUMBER

	if env.RUN_ID then
		local sha = assert(env.SHA, "SHA is not set")
		runner = findPerfRunner(env.RUN_ID)

		if not runner then
			print(`Run {env.RUN_ID} never started its perf job, so there's nothing to publish.`)
			return
		end

		pullRequest = findPullRequest(sha, assert(env.HEAD_REPOSITORY, "HEAD_REPOSITORY is not set"))

		if not pullRequest then
			print(`No open pull request has {sha} as its head, so there's nowhere to publish.`)
			return
		end

		-- A failed comparison may have uploaded nothing, which reads below as a failure.
		command({
			"gh",
			"run",
			"download",
			env.RUN_ID,
			"--repo",
			repository,
			"--name",
			"perf-report",
			"--dir",
			tostring(reportDir),
		}, nil)
	end

	local report = if env.STATUS == "success" and fs.exists(reportPath)
		then fs.readFileToString(reportPath)
		else "The perf comparison failed. See the run for details.\n"

	if env.GITHUB_STEP_SUMMARY then
		local summary = fs.open(env.GITHUB_STEP_SUMMARY, "a")
		fs.write(summary, report)
		fs.close(summary)
	end

	if pullRequest == nil or pullRequest == "" then
		return
	end

	local sha = string.sub(env.SHA or "", 1, 7)
	local footer =
		`<sub>Measured {sha} on \`{runner}\` in [run {runNumber}]({env.RUN_URL}). Changes under 10%, or within how far each side's runs disagree, are treated as noise.</sub>`

	local posted, problem = upsertComment(command, repository, pullRequest, MARKER, `{MARKER}\n{report}\n{footer}\n`)
	assert(posted, problem)
end)
