local test = require("@std/test")

local fetchCheckRuns = require("@root/github/fetchCheckRuns")
local githubTypes = require("@root/github/types")
local testing = require("@root/testing")

type PullState = githubTypes.PullState

local pull: PullState = {
	owner = "vocksel",
	name = "orion",
	number = 341,
	state = "OPEN",
	baseRefName = "main",
	headRefName = "feature",
	draft = false,
	reviewRequests = 0,
	requestedReviewers = {},
	title = "Title",
	url = "u",
	author = "vocksel",
	updatedAt = "now",
	additions = 0,
	deletions = 0,
}

test.case("check runs list each job with its state and whether it's required", function(assert)
	local query = ""
	local found = fetchCheckRuns(function(argv)
		query = argv[5]
		return testing.result(
			true,
			[[{"data":{"c1":{"pullRequest":{"commits":{"nodes":[{"commit":{"statusCheckRollup":{"contexts":{"nodes":[{"__typename":"CheckRun","name":"docs","status":"COMPLETED","conclusion":"FAILURE","isRequired":false},{"__typename":"CheckRun","name":"test","status":"COMPLETED","conclusion":"SUCCESS","isRequired":true},{"__typename":"CheckRun","name":"perf","status":"IN_PROGRESS","conclusion":null,"isRequired":false},{"__typename":"CheckRun","name":"skip","status":"COMPLETED","conclusion":"SKIPPED","isRequired":false},{"__typename":"StatusContext","context":"chromatic","state":"ERROR","isRequired":false}]}}}}]}}}}}]]
		)
	end, { pull })

	assert.strContains(query, "pullRequest(number: 341)")
	assert.strContains(query, "isRequired(pullRequestNumber: 341)")

	local runs = found["vocksel/orion#341"] or {}
	local states: { string } = {}

	for _, run in runs do
		table.insert(states, `{run.name}:{run.state}:{run.required}`)
	end

	assert.eq(
		table.concat(states, " "),
		"docs:failed:false test:passed:true perf:pending:false skip:other:false chromatic:failed:false"
	)
end)

test.case("check runs skip a pull request the query couldn't find", function(assert)
	local found = fetchCheckRuns(function()
		return testing.result(true, [[{"data":{"c1":{"pullRequest":null}}}]])
	end, { pull })

	assert.eq(found["vocksel/orion#341"], nil)
end)
