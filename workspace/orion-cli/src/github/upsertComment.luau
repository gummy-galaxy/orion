local types = require("@root/types")

type CommandRunner = types.CommandRunner

-- Posts `body` as a comment on a pull request or issue, replacing the first
-- comment by the bot that starts with `marker`. The body should start with the
-- same marker so the next run finds it.
local function upsertComment(
	run: CommandRunner,
	repository: string,
	issueNumber: string,
	marker: string,
	body: string
): (boolean, string?)
	local listed = run({
		"gh",
		"api",
		`repos/{repository}/issues/{issueNumber}/comments`,
		"--paginate",
		"--jq",
		`.[] | select(.user.login == "github-actions[bot]" and (.body | startswith("{marker}"))) | .id`,
	}, nil)

	if not listed.ok then
		return false, if listed.stderr ~= "" then listed.stderr else "could not list the comments"
	end

	local commentId = string.match(listed.stdout, "%d+")

	local argv = if commentId
		then { "gh", "api", "-X", "PATCH", `repos/{repository}/issues/comments/{commentId}` }
		else { "gh", "api", `repos/{repository}/issues/{issueNumber}/comments` }
	table.insert(argv, "-f")
	table.insert(argv, `body={body}`)

	local posted = run(argv, nil)

	if not posted.ok then
		return false, if posted.stderr ~= "" then posted.stderr else "GitHub did not accept the comment"
	end

	return true, nil
end

return upsertComment
