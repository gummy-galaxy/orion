local json = require("@std/json")
local test = require("@std/test")

local store = require("@root/store")
local testing = require("@root/testing")

test.case("ready lists startable work, most unblocking first", function(assert)
	local _, run = testing.createHarness("ready")
	local text = run({ "ready" })
	assert.strContains(text, "ci")
	assert.strContains(text, "unblocks 1")
	assert.strNotContains(text, "pub")
end)

test.case("add, link, and done change the shared data", function(assert)
	local dir, run = testing.createHarness("edit")
	assert.strContains(run({ "add", "Write", "release", "notes", "--group", "ws" }), "Added write-release-notes")
	run({ "link", "pub", "write-release-notes" })
	local shown = json.asObject(json.deserialize(run({ "show", "write-release-notes", "--json" })) :: json.Value)
	assert.eq(shown and shown.status, "blocked")
	run({ "done", "ci" })
	run({ "done", "pub" })
	assert.eq(store.load(dir).revision, 4)
	assert.strContains(run({ "ready" }), "write-release-notes")
end)

test.case("group parses comma-separated ids with spaces and empty entries", function(assert)
	local dir, run = testing.createHarness("group-items")
	run({ "group", "Milestone", "--items", " ci, pub, , " })
	local doc = store.load(dir)
	assert.eq(doc.nodes[2].parentId, doc.nodes[3].parentId)
	assert.eq(doc.nodes[2].parentId == "ws", false)
end)

test.case("set arranges a group and show reports it", function(assert)
	local dir, run = testing.createHarness("arrange")
	local shown = json.asObject(json.deserialize(run({ "show", "ws", "--json" })) :: json.Value)
	assert.eq(shown and shown.arrange, "auto")
	run({ "set", "ws", "--arrange", "custom" })
	shown = json.asObject(json.deserialize(run({ "show", "ws", "--json" })) :: json.Value)
	assert.eq(shown and shown.arrange, "custom")
	assert.strContains(run({ "show", "ws" }), "arrange  custom")
	run({ "set", "ws", "--arrange", "auto" })
	assert.eq(store.load(dir).nodes[1].data.layout, "refit")
	assert.throwsWith("only groups take an arrangement", function()
		run({ "set", "pub", "--arrange", "custom" })
	end)
	local item = json.asObject(json.deserialize(run({ "show", "pub", "--json" })) :: json.Value)
	assert.eq(item and item.arrange, nil)
end)

test.case("sync writes GitHub state through the command runner", function(assert)
	local dir, run = testing.createHarness("sync")
	local text = run({ "sync" }, function(argv)
		if argv[5]:find("pullRequests", 1, true) then
			return testing.result(true, [[{"data":{"viewer":{"login":"vocksel","pullRequests":{"nodes":[]}}}}]])
		elseif argv[5]:find("search(", 1, true) then
			return testing.result(true, [[{"data":{"search":{"nodes":[]}}}]])
		end

		return testing.result(
			true,
			[[{"data":{"p1":{"pullRequest":{"number":658,"title":"Report release health to PostHog","url":"u","state":"MERGED","isDraft":false,"reviewDecision":null,"reviewRequests":{"totalCount":0},"author":{"login":"vocksel"},"updatedAt":"2026-10-04T01:00:00Z","additions":120,"deletions":30,"commits":{"nodes":[{"commit":{"statusCheckRollup":{"state":"SUCCESS"}}}]}}}}}]]
		)
	end)

	assert.strContains(text, "ci: active → done")
	local item = store.load(dir).nodes[2]
	assert.eq(item.data.status, "done")
	local recorded = json.asObject(item.data.github)
	assert.eq(recorded and recorded.state, "MERGED")
	assert.eq(recorded and recorded.checks, "SUCCESS")
	assert.eq(recorded and recorded.additions, 120)
	assert.eq(recorded and recorded.mine, true)
end)

test.case("sync --dry-run leaves the data alone", function(assert)
	local dir, run = testing.createHarness("dry")
	run({ "sync", "--dry-run" }, function(argv)
		if argv[5]:find("pullRequests", 1, true) then
			return testing.result(true, [[{"data":{"viewer":{"login":"vocksel","pullRequests":{"nodes":[]}}}}]])
		elseif argv[5]:find("search(", 1, true) then
			return testing.result(true, [[{"data":{"search":{"nodes":[]}}}]])
		end

		return testing.result(
			true,
			[[{"data":{"p1":{"pullRequest":{"number":658,"title":"t","url":"u","state":"MERGED","isDraft":false,"reviewRequests":{"totalCount":0}}}}}]]
		)
	end)

	assert.eq(store.load(dir).revision, 0)
end)

test.case("matches reads stored suggestions without a runner", function(assert)
	local dir, run = testing.createHarness("matches")
	store.transaction(dir, function(doc)
		doc.github = json.object({
			viewer = "vocksel",
			checkedAt = "now",
			unplaced = {
				json.object({
					repo = "flipbook",
					number = 670,
					title = "Release health dashboard",
					matches = { json.object({ id = "pub", score = 0.72 }) },
				}),
			},
		})
	end)

	assert.strContains(run({ "matches" }), "flipbook#670")
	assert.strContains(run({ "matches" }), "pub")
	local values = json.asArray(json.deserialize(run({ "matches", "--json" })) :: json.Value)
	assert.eq(values and #values, 1)
end)

test.case("sync records unplaced authored pulls without adding review request cards", function(assert)
	local dir, run = testing.createHarness("review")
	local isSearched = false
	local output = run({ "sync" }, function(argv)
		if argv[5]:find("pullRequests", 1, true) then
			return testing.result(
				true,
				[[{"data":{"viewer":{"login":"vocksel","pullRequests":{"nodes":[{"number":670,"title":"Add release health dashboard","url":"u670","state":"OPEN","isDraft":false,"author":{"login":"vocksel"},"updatedAt":"2026-10-04T18:00:00Z","additions":80,"deletions":4,"repository":{"name":"flipbook","owner":{"login":"flipbook-labs"}}}]}}}}]]
			)
		elseif argv[5]:find("review-requested", 1, true) then
			isSearched = true
		end

		return testing.result(true, [[{"data":{"p1":{"pullRequest":null}}}]])
	end)
	assert.eq(isSearched, false)
	assert.eq(output:find("Review requests", 1, true), nil)
	local doc = store.load(dir)
	for _, item in doc.nodes do
		assert.neq(item.id, "reviews")
	end
	local top = doc.github
	local unplaced = if top then json.asArray(top.unplaced) else nil
	assert.eq(unplaced and #unplaced, 1)
	assert.strContains(run({ "matches" }), "flipbook#670")
end)
