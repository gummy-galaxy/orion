local getString = require("@root/github/getString")
local githubTypes = require("@root/github/types")
local json = require("@std/json")

type PullState = githubTypes.PullState

local function parsePull(object: json.Object, owner: string, name: string, host: string?): PullState?
	local number, state, url = object.number, object.state, object.url

	if type(number) ~= "number" or type(state) ~= "string" or type(url) ~= "string" then
		return nil
	end

	local requests = json.asObject(object.reviewRequests)
	local requestedReviewers: { string } = {}

	for _, raw in (if requests then json.asArray(requests.nodes) else nil) or {} do
		local node = json.asObject(raw)
		local reviewer = if node then json.asObject(node.requestedReviewer) else nil
		local login = if reviewer then getString(reviewer.login) else nil

		if login then
			table.insert(requestedReviewers, login)
		end
	end

	local author = json.asObject(object.author)
	local commits = json.asObject(object.commits)
	local commitNodes = if commits then json.asArray(commits.nodes) else nil
	local last = if commitNodes then json.asObject(commitNodes[1]) else nil
	local commit = if last then json.asObject(last.commit) else nil
	local rollup = if commit then json.asObject(commit.statusCheckRollup) else nil
	return {
		owner = owner,
		name = name,
		number = number,
		state = state,
		baseRefName = getString(object.baseRefName) or "",
		headRefName = getString(object.headRefName) or "",
		draft = object.isDraft == true,
		reviewDecision = getString(object.reviewDecision),
		reviewRequests = if requests and type(requests.totalCount) == "number" then requests.totalCount else 0,
		requestedReviewers = requestedReviewers,
		title = getString(object.title) or "",
		url = url,
		author = if author then getString(author.login) or "" else "",
		updatedAt = getString(object.updatedAt) or "",
		additions = if type(object.additions) == "number" then object.additions else 0,
		deletions = if type(object.deletions) == "number" then object.deletions else 0,
		checks = if rollup then getString(rollup.state) else nil,
		branch = getString(object.headRefName),
		body = getString(object.body),
		host = host,
	}
end

return parsePull
