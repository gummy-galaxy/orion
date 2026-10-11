--[[
	Adds the priority label to a pull request, creating the label first when the repository lacks it. The Beelink
	supervisor runs the queued jobs of labeled pull requests first, so the label stays on until the perf job starts.
]]
local process = require("@std/process")

local label = require("@root/prioritize/label")
local runGh = require("@root/prioritize/runGh")

local env = process.env
local repository = assert(env.GITHUB_REPOSITORY, "GITHUB_REPOSITORY is not set")
local pullRequest = assert(env.PR, "PR is not set")

runGh({
	"label",
	"create",
	label.NAME,
	"--repo",
	repository,
	"--color",
	label.COLOR,
	"--description",
	label.DESCRIPTION,
	"--force",
})

runGh({ "pr", "edit", pullRequest, "--repo", repository, "--add-label", label.NAME })

print(`Added {label.NAME} to PR #{pullRequest}`)
