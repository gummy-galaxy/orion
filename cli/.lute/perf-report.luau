--[[
	Publishes the perf comparison in app/.perf/report.md from CI's perf job. It adds the report to the job summary
	and keeps it in one pull request comment, replacing the comment an earlier run left. When the comparison fails, the
	comment says so and links the run.
]]
local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")

local runScript = require("@root/runScript")

local MARKER = "<!-- orion-perf -->"

local env = process.env
local perfDir = path.resolve("../app/.perf")
local reportPath = path.join(perfDir, "report.md")
local commentPath = path.join(perfDir, "comment.md")
local repository = assert(env.GITHUB_REPOSITORY, "GITHUB_REPOSITORY is not set")
local pullRequest = assert(env.PR, "PR is not set")

local function gh(args: { string }): string
	local result = process.run({ "gh", table.unpack(args) })
	assert(result.ok, `gh {table.concat(args, " ")} failed: {result.stderr}`)

	return result.stdout
end

runScript(function()
	local report = if env.STATUS == "success" and fs.exists(reportPath)
		then fs.readFileToString(reportPath)
		else "The perf comparison failed. See the run for details.\n"

	if env.GITHUB_STEP_SUMMARY then
		local summary = fs.open(env.GITHUB_STEP_SUMMARY, "a")
		fs.write(summary, report)
		fs.close(summary)
	end

	local sha = string.sub(env.SHA or "", 1, 7)
	local footer =
		`<sub>Measured {sha} on \`{env.RUNNER_NAME}\` in [run {env.GITHUB_RUN_NUMBER}]({env.RUN_URL}). Changes under 10%, or within how far each side's runs disagree, are treated as noise.</sub>`

	if not fs.exists(perfDir) then
		fs.createDirectory(perfDir, { makeParents = true })
	end

	fs.writeStringToFile(commentPath, `{MARKER}\n{report}\n{footer}\n`)

	local existing = gh({
		"api",
		`repos/{repository}/issues/{pullRequest}/comments`,
		"--paginate",
		"--jq",
		`.[] | select(.user.login == "github-actions[bot]" and (.body | startswith("{MARKER}"))) | .id`,
	})
	local commentId = string.match(existing, "%d+")

	if commentId then
		gh({ "api", "-X", "PATCH", `repos/{repository}/issues/comments/{commentId}`, "-F", `body=@{commentPath}` })
	else
		gh({ "api", `repos/{repository}/issues/{pullRequest}/comments`, "-F", `body=@{commentPath}` })
	end
end)
