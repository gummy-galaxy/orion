--[[
	Publishes the perf comparison in app/.perf/report.md from CI's perf job. It adds the report to the job summary
	and, for a pull request, keeps it in one comment, replacing the comment an earlier run left. When the comparison
	fails, the comment says so and links the run. A push to main has no pull request, so its report stays in the summary.
]]
local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")

local command = require("@root/command")
local runScript = require("@root/runScript")
local upsertComment = require("@root/github/upsertComment")

local MARKER = "<!-- orion-perf -->"

local env = process.env
local reportPath = path.resolve("../app/.perf/report.md")
local repository = assert(env.GITHUB_REPOSITORY, "GITHUB_REPOSITORY is not set")
local pullRequest = env.PR

runScript(function()
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
		`<sub>Measured {sha} on \`{env.RUNNER_NAME}\` in [run {env.GITHUB_RUN_NUMBER}]({env.RUN_URL}). Changes under 10%, or within how far each side's runs disagree, are treated as noise.</sub>`

	local posted, problem = upsertComment(command, repository, pullRequest, MARKER, `{MARKER}\n{report}\n{footer}\n`)
	assert(posted, problem)
end)
