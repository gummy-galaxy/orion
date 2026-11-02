--[[
	Links a pull request to the Storybook that Chromatic published for its head
	commit, and to each story in it. Stories that load a file the pull request
	changes come first. It reads the stories from the build in
	workspace/orion-app/storybook-static and keeps the links in one pull request
	comment, replacing the comment an earlier push left, so they always point at
	the newest build.
]]
local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")

local command = require("@workspace/orion-cli/src/common/process/command")
local findTouchedStories = require("../lib/storybook/findTouchedStories")
local formatStorybookComment = require("../lib/storybook/formatStorybookComment")
local parseStoryIndex = require("../lib/storybook/parseStoryIndex")
local upsertCommentAsync = require("@workspace/orion-cli/src/sources/github/api/upsertCommentAsync")

local MARKER = "<!-- orion-storybook -->"
local STORYBOOK_ROOT = "workspace/orion-app"

local env = process.env

-- Reads a file by its path from the repository root, or returns nil for a
-- missing file or a folder.
local function readFile(file: string): string?
	local succeeded, contents = pcall(fs.readFileToString, file)

	return if succeeded then contents else nil
end

local function getChangedFiles(repository: string, pullRequest: string): { string }
	local listed = command({
		"gh",
		"api",
		`repos/{repository}/pulls/{pullRequest}/files`,
		"--paginate",
		"--jq",
		".[].filename",
	}, nil)
	assert(listed.ok, listed.stderr)

	local files = {}

	for file in string.gmatch(listed.stdout, "[^\n]+") do
		table.insert(files, file)
	end

	return files
end

-- Every story picks up the app's stylesheets and Storybook's preview, so a
-- change to either can show anywhere.
local function changesStyles(files: { string }): boolean
	for _, file in files do
		local inStorybook = string.sub(file, 1, #STORYBOOK_ROOT + 1) == `{STORYBOOK_ROOT}/`

		if inStorybook and (path.extname(file) == ".css" or string.find(file, "/%.storybook/preview%.")) then
			return true
		end
	end

	return false
end

local function commentStorybook()
	local repository = assert(env.GITHUB_REPOSITORY, "GITHUB_REPOSITORY is not set")
	local pullRequest = assert(env.PR, "PR is not set")
	local storybookUrl = assert(env.STORYBOOK_URL, "STORYBOOK_URL is not set")
	local indexText = readFile(`{STORYBOOK_ROOT}/storybook-static/index.json`)
	local stories = if indexText then parseStoryIndex(indexText, STORYBOOK_ROOT, readFile) else {}
	local changedFiles = getChangedFiles(repository, pullRequest)

	local sha = string.sub(env.SHA or "", 1, 7)
	local footer =
		`<sub>Published from {sha} in [run {env.GITHUB_RUN_NUMBER}]({env.RUN_URL}). Each push replaces this comment.</sub>`

	local report = formatStorybookComment({
		storybookUrl = storybookUrl,
		stories = stories,
		touched = findTouchedStories(stories, changedFiles, readFile),
		stylesChanged = changesStyles(changedFiles),
	})

	local posted, problem =
		upsertCommentAsync(command, repository, pullRequest, MARKER, `{MARKER}\n{report}\n{footer}\n`)
	assert(posted, problem)

	print(`Linked {storybookUrl} and {#stories} stories from #{pullRequest}`)
end

return commentStorybook
