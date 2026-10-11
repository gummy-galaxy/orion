--[[
	Removes the priority label from a pull request once the watch is over, whether the perf job started, was skipped, or
	the watch timed out.
]]
local process = require("@std/process")

local label = require("@root/prioritize/label")
local runGh = require("@root/prioritize/runGh")

local env = process.env
local repository = assert(env.GITHUB_REPOSITORY, "GITHUB_REPOSITORY is not set")
local pullRequest = assert(env.PR, "PR is not set")

runGh({ "pr", "edit", pullRequest, "--repo", repository, "--remove-label", label.NAME })

print(`Removed {label.NAME} from PR #{pullRequest}`)
