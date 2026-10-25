local test = require("@std/test")

local pollNotifications = require("@root/github/pollNotifications")
local testing = require("@root/testing")

local LAST_MODIFIED = "Sun, 18 Oct 2026 15:53:33 GMT"

local function response(status: string, body: string?): string
	return `HTTP/2.0 {status}\nLast-Modified: {LAST_MODIFIED}\r\nX-Poll-Interval: 90\r\n\r\n{body or ""}`
end

test.case("the first poll only records the newest notification's time", function(assert)
	local calls: { { string } } = {}
	local poll = pollNotifications(function(argv)
		table.insert(calls, argv)
		return testing.result(true, response("200 OK", "[]"))
	end, "github.com", nil)

	assert.eq(#calls, 1)
	assert.eq(calls[1][#calls[1]], "/notifications?all=true&per_page=1")
	assert.eq(table.find(calls[1], "--header"), nil)
	assert.eq(poll.changed, false)
	assert.eq(poll.lastModified, LAST_MODIFIED)
	assert.eq(poll.interval, 90)
	assert.eq(#poll.pulls, 0)
end)

test.case("an unchanged poll answers 304 and keeps its time", function(assert)
	local argv: { string } = {}
	local poll = pollNotifications(function(given)
		argv = given
		return testing.result(false, response("304 Not Modified"), "gh: HTTP 304")
	end, "github.com", LAST_MODIFIED)

	assert.eq(argv[table.find(argv, "--header") :: number + 1], `If-Modified-Since: {LAST_MODIFIED}`)
	assert.strContains(argv[#argv], "since=2026-10-18T15:53:33Z")
	assert.eq(poll.changed, false)
	assert.eq(poll.lastModified, LAST_MODIFIED)
	assert.eq(poll.interval, 90)
end)

test.case("a changed poll names each pull request once and skips other subjects", function(assert)
	local body = [=[[
		{"subject":{"type":"PullRequest","url":"https://api.github.com/repos/vocksel/orion/pulls/442"}},
		{"subject":{"type":"PullRequest","url":"https://api.github.com/repos/vocksel/orion/pulls/442"}},
		{"subject":{"type":"Issue","url":"https://api.github.com/repos/vocksel/orion/issues/366"}},
		{"subject":{"type":"PullRequest","url":"https://api.github.com/repos/flipbook-labs/flipbook/pulls/658"}}
	]]=]
	local poll = pollNotifications(function()
		return testing.result(true, response("200 OK", body))
	end, "github.com", "Sat, 17 Oct 2026 01:02:03 GMT")

	assert.eq(poll.changed, true)
	assert.eq(poll.lastModified, LAST_MODIFIED)
	assert.eq(#poll.pulls, 2)
	assert.eq(poll.pulls[1].owner, "vocksel")
	assert.eq(poll.pulls[1].number, 442)
	assert.eq(poll.pulls[1].host, nil)
	assert.eq(poll.pulls[2].name, "flipbook")
end)

test.case("an enterprise poll asks its host and keeps the host on each pull request", function(assert)
	local argv: { string } = {}
	local poll = pollNotifications(function(given)
		argv = given
		return testing.result(
			true,
			response(
				"200 OK",
				[=[[{"subject":{"type":"PullRequest","url":"https://github.example.com/api/v3/repos/team/app/pulls/7"}}]]=]
			)
		)
	end, "github.example.com", LAST_MODIFIED)

	assert.eq(argv[table.find(argv, "--hostname") :: number + 1], "github.example.com")
	assert.eq(poll.pulls[1].host, "github.example.com")
	assert.eq(poll.pulls[1].number, 7)
end)

test.case("a failed poll raises with gh's message", function(assert)
	assert.throws(function()
		pollNotifications(function()
			return testing.result(false, "HTTP/2.0 401 Unauthorized\n\n{}", "gh: Bad credentials (HTTP 401)")
		end, "github.com", LAST_MODIFIED)
	end)
end)
