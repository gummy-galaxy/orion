--[[
	Keeps a CI report in one pull request comment. The comment starts with marker, so a later run finds the comment
	an earlier one left and replaces it instead of adding another. The body is written to bodyPath for gh to read.
]]
local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")

local function gh(args: { string }): string
	local result = process.run({ "gh", table.unpack(args) })
	assert(result.ok, `gh {table.concat(args, " ")} failed: {result.stderr}`)

	return result.stdout
end

local function publishPullRequestComment(marker: string, body: string, bodyPath: path.Pathlike)
	local repository = assert(process.env.GITHUB_REPOSITORY, "GITHUB_REPOSITORY is not set")
	local pullRequest = assert(process.env.PR, "PR is not set")

	local bodyFile = path.format(bodyPath)
	fs.writeStringToFile(bodyFile, `{marker}\n{body}`)

	local existing = gh({
		"api",
		`repos/{repository}/issues/{pullRequest}/comments`,
		"--paginate",
		"--jq",
		`.[] | select(.user.login == "github-actions[bot]" and (.body | startswith("{marker}"))) | .id`,
	})
	local commentId = string.match(existing, "%d+")

	if commentId then
		gh({ "api", "-X", "PATCH", `repos/{repository}/issues/comments/{commentId}`, "-F", `body=@{bodyFile}` })
	else
		gh({ "api", `repos/{repository}/issues/{pullRequest}/comments`, "-F", `body=@{bodyFile}` })
	end
end

return publishPullRequestComment
