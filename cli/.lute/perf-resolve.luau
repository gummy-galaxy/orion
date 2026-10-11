--[[
	Resolves the pull request that a perf run measures to its head commit and base branch, and writes them to
	GITHUB_OUTPUT for the perf job. The run may come from a pull request event or from workflow_dispatch, so the perf job
	reads both from here.
]]
local fs = require("@std/fs")
local process = require("@std/process")

local command = require("@root/command")
local getPullTarget = require("@root/perf/getPullTarget")

local env = process.env
local repository = assert(env.GITHUB_REPOSITORY, "GITHUB_REPOSITORY is not set")
local pullRequest = assert(env.PR, "PR is not set")
local outputPath = assert(env.GITHUB_OUTPUT, "GITHUB_OUTPUT is not set")

local target = getPullTarget(command, repository, pullRequest)

local output = fs.open(outputPath, "a")
fs.write(output, `head_sha={target.headSha}\nbase_ref={target.baseRef}\n`)
fs.close(output)

print(`Pull request #{pullRequest} is at {target.headSha}, measured against {target.baseRef}`)
