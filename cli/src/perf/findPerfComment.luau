local json = require("@std/json")
local perfComment = require("@root/perf/perfComment")
local types = require("@root/types")

type CommandRunner = types.CommandRunner

export type PerfComment = {
	id: string,
	body: string,
}

-- Finds the perf comment CI keeps on a pull request. Returns the first one, or nil when there is none.
local function findPerfComment(run: CommandRunner, repository: string, pullRequest: string): PerfComment?
	local result = run({
		"gh",
		"api",
		`repos/{repository}/issues/{pullRequest}/comments`,
		"--paginate",
		"--jq",
		`.[] | select(.user.login == "github-actions[bot]" and (.body | startswith("{perfComment.MARKER}"))) | [.id, .body] | @json`,
	}, nil)

	if not result.ok then
		error(`gh api comments failed: {result.stderr}`, 0)
	end

	-- Each match prints as one line holding a JSON pair of the comment's id and body.
	for line in string.gmatch(result.stdout, "[^\n]+") do
		local pair = json.asArray(json.deserialize(line) :: json.Value)

		if pair and typeof(pair[1]) == "number" and typeof(pair[2]) == "string" then
			return {
				id = tostring(pair[1]),
				body = pair[2] :: string,
			}
		end
	end

	return nil
end

return findPerfComment
