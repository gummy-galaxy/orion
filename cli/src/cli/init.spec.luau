local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")
local test = require("@std/test")

local cli = require("@root/cli")
local store = require("@root/store")
local testing = require("@root/testing")

local function harness(name: string)
	local dir = testing.directory(name)
	store.write(
		dir,
		testing.doc({
			testing.group("ws", "Release"),
			testing.task("ci", "Report release health", "active", "ws", { repo = "flipbook", pr = 658 }),
			testing.task("pub", "Publish v2.6.0", "todo", "ws"),
		}, { { "ci", "pub" } })
	)
	local output = {}
	local function run(args: { string }, runner: any?)
		table.clear(output)
		cli.execute(args, {
			dataDir = dir,
			write = function(text)
				table.insert(output, text)
			end,
			runner = runner,
			now = function()
				return "2026-10-04T00:00:00Z"
			end,
		})
		return table.concat(output, "\n")
	end
	return dir, run
end

test.case("ready lists startable work, most unblocking first", function(assert)
	local _, run = harness("ready")
	local text = run({ "ready" })
	assert.strContains(text, "ci")
	assert.strContains(text, "unblocks 1")
	assert.strNotContains(text, "pub")
end)

test.case("focus says when the app isn't reporting", function(assert)
	local _, run = harness("focus-closed")
	assert.strContains(run({ "focus" }), "isn't open")
	local shown = json.asObject(json.deserialize(run({ "focus", "--json" })) :: json.Value)
	assert.eq(shown and shown.appOpen, false)
end)

test.case("focus shows the open group and the selection the app reported", function(assert)
	local dir, run = harness("focus")
	store.transaction(dir, function(doc)
		table.insert(doc.nodes, testing.group("top", "Roadmap"))
		doc.nodes[1].parentId = "top"
	end)
	fs.writeStringToFile(
		path.join(dir, "focus.json"),
		[[{"tab":"t","open":"ws","selected":["pub","gone"],"updatedAt":"2026-10-05T00:00:00Z"}]]
	)
	local text = run({ "focus" })
	assert.strContains(text, "Open: ws  Release  0/2 done, 0 ready, inside Roadmap")
	assert.strContains(text, "pub")
	assert.strNotContains(text, "gone")
	local shown = json.asObject(json.deserialize(run({ "focus", "--json" })) :: json.Value)
	local open = if shown then json.asObject(shown.open) else nil
	local trail = if open then json.asArray(open.path) else nil
	local first = if trail then json.asObject(trail[1]) else nil
	local selected = if shown then json.asArray(shown.selected) else nil
	local item = if selected then json.asObject(selected[1]) else nil
	assert.eq(open and open.id, "ws")
	assert.eq(first and first.id, "top")
	assert.eq(selected and #selected, 1)
	assert.eq(item and item.status, "blocked")
end)

test.case("focus at the top level can select a group", function(assert)
	local dir, run = harness("focus-top")
	fs.writeStringToFile(path.join(dir, "focus.json"), [[{"tab":"t","open":null,"selected":["ws"]}]])
	local text = run({ "focus" })
	assert.strContains(text, "Open: the top level")
	assert.strContains(text, "Release  0/2 done, 0 ready")
	local shown = json.asObject(json.deserialize(run({ "focus", "--json" })) :: json.Value)
	local selected = if shown then json.asArray(shown.selected) else nil
	local group = if selected then json.asObject(selected[1]) else nil
	assert.eq(shown and shown.open, nil)
	assert.eq(group and group.kind, "group")
end)

test.case("add, link, and done change the shared data", function(assert)
	local dir, run = harness("edit")
	assert.strContains(run({ "add", "Write", "release", "notes", "--group", "ws" }), "Added write-release-notes")
	run({ "link", "pub", "write-release-notes" })
	local shown = json.asObject(json.deserialize(run({ "show", "write-release-notes", "--json" })) :: json.Value)
	assert.eq(shown and shown.status, "blocked")
	run({ "done", "ci" })
	run({ "done", "pub" })
	assert.eq(store.load(dir).revision, 4)
	assert.strContains(run({ "ready" }), "write-release-notes")
end)

test.case("sync writes GitHub state through the command runner", function(assert)
	local dir, run = harness("sync")
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
	local dir, run = harness("dry")
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
	local dir, run = harness("matches")
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

test.case("sync creates review requests and unplaced authored pulls", function(assert)
	local dir, run = harness("review")
	local output = run({ "sync" }, function(argv)
		if argv[5]:find("pullRequests", 1, true) then
			return testing.result(
				true,
				[[{"data":{"viewer":{"login":"vocksel","pullRequests":{"nodes":[{"number":670,"title":"Add release health dashboard","url":"u670","state":"OPEN","isDraft":false,"author":{"login":"vocksel"},"updatedAt":"2026-10-04T18:00:00Z","additions":80,"deletions":4,"repository":{"name":"flipbook","owner":{"login":"flipbook-labs"}}}]}}}}]]
			)
		elseif argv[5]:find("search(", 1, true) then
			return testing.result(
				true,
				[[{"data":{"search":{"nodes":[{"number":4,"title":"Review the release","url":"u4","state":"OPEN","isDraft":false,"author":{"login":"colleague"},"updatedAt":"2026-10-04T17:00:00Z","additions":3,"deletions":2,"reviewRequests":{"totalCount":1,"nodes":[{"requestedReviewer":{"login":"vocksel"}}]},"repository":{"name":"storyteller","owner":{"login":"flipbook-labs"}}}]}}}]]
			)
		end
		return testing.result(true, [[{"data":{"p1":{"pullRequest":null}}}]])
	end)
	assert.strContains(output, "Review requests")
	local doc = store.load(dir)
	assert.eq(doc.nodes[5].parentId, "reviews")
	assert.eq(doc.nodes[5].data.who, "you")
	local top = doc.github
	local unplaced = if top then json.asArray(top.unplaced) else nil
	assert.eq(unplaced and #unplaced, 1)
	assert.strContains(run({ "matches" }), "flipbook#670")
end)
