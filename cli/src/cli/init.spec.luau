local json = require("@std/json")
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
	local text = run({ "sync" }, function()
		return testing.result(
			true,
			[[{"data":{"p1":{"pullRequest":{"number":658,"title":"Report release health to PostHog","url":"u","state":"MERGED","isDraft":false,"reviewDecision":null,"reviewRequests":{"totalCount":0}}}}}]]
		)
	end)
	assert.strContains(text, "ci: active → done")
	local item = store.load(dir).nodes[2]
	assert.eq(item.data.status, "done")
	local recorded = json.asObject(item.data.github)
	assert.eq(recorded and recorded.state, "MERGED")
end)

test.case("sync --dry-run leaves the data alone", function(assert)
	local dir, run = harness("dry")
	run({ "sync", "--dry-run" }, function()
		return testing.result(
			true,
			[[{"data":{"p1":{"pullRequest":{"number":658,"title":"t","url":"u","state":"MERGED","isDraft":false,"reviewRequests":{"totalCount":0}}}}}]]
		)
	end)
	assert.eq(store.load(dir).revision, 0)
end)
