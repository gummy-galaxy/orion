--[[
	Publishes the app's test coverage from CI's app job. It reads the totals npm run coverage writes to
	workspace/orion-app/coverage/coverage-summary.json, adds them to the job summary, and keeps them in one pull request comment,
	replacing the comment an earlier run left.
]]
local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")
local process = require("@std/process")

local command = require("@cli/command")
local runScript = require("@cli/runScript")
local upsertCommentAsync = require("@cli/github/upsertCommentAsync")

type Metric = { total: number, covered: number, pct: number }

local MARKER = "<!-- orion-coverage -->"
local METRICS = { "statements", "branches", "functions", "lines" }

local env = process.env
local summaryPath = path.resolve("workspace/orion-app/coverage/coverage-summary.json")
local repository = assert(env.GITHUB_REPOSITORY, "GITHUB_REPOSITORY is not set")
local pullRequest = assert(env.PR, "PR is not set")

runScript(function()
	local summary = json.deserialize(fs.readFileToString(summaryPath)) :: any
	local totals: { [string]: Metric } = summary.total

	local rows = { "| | Covered | Total | % |", "| --- | ---: | ---: | ---: |" }

	for _, name in METRICS do
		local metric = totals[name]
		local label = string.upper(string.sub(name, 1, 1)) .. string.sub(name, 2)
		table.insert(rows, `| {label} | {metric.covered} | {metric.total} | {string.format("%.2f", metric.pct)}% |`)
	end

	local report = `### App coverage\n\n{table.concat(rows, "\n")}\n`

	if env.GITHUB_STEP_SUMMARY then
		local stepSummary = fs.open(env.GITHUB_STEP_SUMMARY, "a")
		fs.write(stepSummary, report)
		fs.close(stepSummary)
	end

	local sha = string.sub(env.SHA or "", 1, 7)
	local footer = `<sub>Measured {sha} in [run {env.GITHUB_RUN_NUMBER}]({env.RUN_URL}).</sub>`

	local posted, problem =
		upsertCommentAsync(command, repository, pullRequest, MARKER, `{MARKER}\n{report}\n{footer}\n`)
	assert(posted, problem)
end)
