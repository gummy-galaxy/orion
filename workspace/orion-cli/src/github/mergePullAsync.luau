local types = require("@root/types")

type CommandRunner = types.CommandRunner

local METHOD_FLAGS: { [string]: string } = { SQUASH = "--squash", MERGE = "--merge", REBASE = "--rebase" }

local function getError(result: types.CommandResult, fallback: string): string
	return if result.stderr ~= "" then result.stderr else fallback
end

-- Merges a pull request the way the viewer last merged in its repository, only
-- if its head is still `head`.
local function mergePullAsync(run: CommandRunner, url: string, head: string): (boolean, string?)
	local host, owner, name = url:match("^https://([%w.-]+)/([%w_.-]+)/([%w_.-]+)/pull/[1-9]%d*/?$")

	if not host or not owner or not name then
		return false, "expected a pull request URL"
	end

	local view = run({
		"gh",
		"repo",
		"view",
		`{host}/{owner}/{name}`,
		"--json",
		"viewerDefaultMergeMethod",
		"--jq",
		".viewerDefaultMergeMethod",
	}, nil)

	if not view.ok then
		return false, getError(view, "could not read the repository's merge method")
	end

	local flag = METHOD_FLAGS[view.stdout:match("^%s*(%u+)%s*$") or ""] or METHOD_FLAGS.SQUASH
	local merge = run({ "gh", "pr", "merge", url, flag, "--match-head-commit", head }, nil)

	if not merge.ok then
		return false, getError(merge, "GitHub could not merge this pull request")
	end

	return true, nil
end

return mergePullAsync
