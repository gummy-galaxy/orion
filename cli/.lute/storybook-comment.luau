--[[
	Links a pull request to the Storybook that Chromatic published for its head commit. It keeps the link in one pull
	request comment, replacing the comment an earlier push left, so the link always points at the newest build.
]]
local process = require("@std/process")

local command = require("@root/command")
local runScript = require("@root/runScript")
local upsertComment = require("@root/github/upsertComment")

local MARKER = "<!-- orion-storybook -->"

local env = process.env
local repository = assert(env.GITHUB_REPOSITORY, "GITHUB_REPOSITORY is not set")
local pullRequest = assert(env.PR, "PR is not set")
local storybookUrl = assert(env.STORYBOOK_URL, "STORYBOOK_URL is not set")

local sha = string.sub(env.SHA or "", 1, 7)
local footer =
	`<sub>Published from {sha} in [run {env.GITHUB_RUN_NUMBER}]({env.RUN_URL}). Each push replaces this comment.</sub>`

local body = `{MARKER}\n**Storybook:** [Open this pull request's Storybook]({storybookUrl})\n\n{footer}\n`

runScript(function()
	local posted, problem = upsertComment(command, repository, pullRequest, MARKER, body)
	assert(posted, problem)

	print(`Linked {storybookUrl} from #{pullRequest}`)
end)
