--[[
	Checks whether the pull request's perf comment already reports a finished comparison of this head commit. CI's perf
	job runs it first, so a commit that an earlier run already measured, such as one started with workflow_dispatch,
	finishes without measuring again. Writes measured=true or measured=false to GITHUB_OUTPUT. If the lookup fails, the
	commit gets measured, so a failed lookup never skips a measurement.
]]
local fs = require("@std/fs")
local process = require("@std/process")

local command = require("@root/command")
local findPerfComment = require("@root/perf/findPerfComment")
local isMeasured = require("@root/perf/isMeasured")

local env = process.env
local repository = assert(env.GITHUB_REPOSITORY, "GITHUB_REPOSITORY is not set")
local pullRequest = assert(env.PR, "PR is not set")
local sha = assert(env.SHA, "SHA is not set")
local outputPath = assert(env.GITHUB_OUTPUT, "GITHUB_OUTPUT is not set")

local measured = false
local succeeded, comment = pcall(findPerfComment, command, repository, pullRequest)

if not succeeded then
	print(`::warning::Could not read the perf comment, so {sha} gets measured: {comment}`)
elseif comment and isMeasured(comment.body, sha) then
	measured = true
	print(`Pull request #{pullRequest} already has a finished report for {sha}, so there is nothing to measure`)
end

local output = fs.open(outputPath, "a")
fs.write(output, `measured={tostring(measured)}\n`)
fs.close(output)
