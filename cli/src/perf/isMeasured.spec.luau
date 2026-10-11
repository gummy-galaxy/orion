local test = require("@std/test")

local isMeasured = require("@root/perf/isMeasured")
local perfComment = require("@root/perf/perfComment")

local SHA = "0123456789abcdef0123456789abcdef01234567"

local function footer(sha: string): string
	return `<sub>Measured {string.sub(sha, 1, 7)} on runner in run 12.</sub>`
end

test.case("isMeasured finds a finished report for the same commit", function(assert)
	local body = `{perfComment.MARKER}\n## Perf\n\nNo regressions.\n{footer(SHA)}\n`

	assert.eq(isMeasured(body, SHA), true)
end)

test.case("isMeasured ignores a report for another commit", function(assert)
	local body = `{perfComment.MARKER}\n## Perf\n{footer("fedcba9876543210fedcba9876543210fedcba98")}\n`

	assert.eq(isMeasured(body, SHA), false)
end)

test.case("isMeasured does not count a failed comparison", function(assert)
	local body = `{perfComment.MARKER}\n{perfComment.FAILURE}\n{footer(SHA)}\n`

	assert.eq(isMeasured(body, SHA), false)
end)

test.case("isMeasured rejects an empty commit", function(assert)
	local body = `{perfComment.MARKER}\n## Perf\n{footer(SHA)}\n`

	assert.eq(isMeasured(body, ""), false)
end)
