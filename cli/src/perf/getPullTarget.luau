local types = require("@root/types")

type CommandRunner = types.CommandRunner

export type PullTarget = {
	headSha: string,
	baseRef: string,
}

-- Reads the head commit and base branch of a pull request, which the perf comparison measures and compares against.
local function getPullTarget(run: CommandRunner, repository: string, pullRequest: string): PullTarget
	assert(string.match(pullRequest, "^%d+$"), `pull request must be a number, got {pullRequest}`)

	local result = run({
		"gh",
		"api",
		`repos/{repository}/pulls/{pullRequest}`,
		"--jq",
		"[.head.sha, .base.ref] | @tsv",
	}, nil)

	assert(result.ok, `gh api pulls failed: {result.stderr}`)

	local headSha, baseRef = string.match(result.stdout, "^(%x+)\t([^\t\n]+)")

	assert(headSha and baseRef, `unexpected pull request response: {result.stdout}`)

	return {
		headSha = headSha,
		baseRef = baseRef,
	}
end

return getPullTarget
