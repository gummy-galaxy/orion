local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")
local test = require("@std/test")

local findRef = require("@root/refs/findRef")
local getVersion = require("@root/getVersion")
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

test.case("set renames items and groups and reports the new labels", function(assert)
	local dir, run = testing.createHarness("set-label")
	assert.eq(run({ "set", "pub", "--label", "New item name" }), "Updated pub · New item name")
	assert.eq(run({ "set", "ws", "--label", "New group name" }), "Updated ws · New group name")
	local doc = store.load(dir)
	assert.eq(doc.nodes[1].data.label, "New group name")
	assert.eq(doc.nodes[3].data.label, "New item name")
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
	local recorded = (findRef(item, "pull") :: any).details
	assert.eq(recorded and recorded.state, "MERGED")
	assert.eq(recorded and recorded.checks, "SUCCESS")
	assert.eq(recorded and recorded.additions, 120)
	assert.eq(recorded and recorded.mine, true)
end)

test.case("ingest refreshes pull request cards without any sources configured", function(assert)
	local dir, run = testing.createHarness("ingest-refresh")
	local text = run({ "ingest" }, function(argv)
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

	assert.strContains(text, "Checked 1 pull requests on GitHub.")
	assert.strContains(text, "ci: active → done")
	assert.eq(store.load(dir).nodes[2].data.status, "done")
end)

test.case("sync still works and points to ingest", function(assert)
	local _, run = testing.createHarness("sync-deprecated")
	local text = run({ "sync", "--dry-run" }, function(argv)
		if argv[5]:find("pullRequests", 1, true) then
			return testing.result(true, [[{"data":{"viewer":{"login":"vocksel","pullRequests":{"nodes":[]}}}}]])
		end

		return testing.result(true, [[{"data":{"search":{"nodes":[]}}}]])
	end)

	assert.strContains(text, "`orion ingest` refreshes pull requests too")
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
					repo = "flipbook-labs/flipbook",
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

test.case("set puts a cover and background on a group, and needs the cover image in the workspace", function(assert)
	local dir, run = testing.createHarness("set-group-style")
	assert.throws(function()
		run({ "set", "ws", "--cover", "image-missing.png" })
	end)
	fs.createDirectory(path.join(dir, "assets"), { makeParents = true })
	fs.writeStringToFile(path.join(dir, "assets", "image-logo.png"), "bytes")
	run({ "set", "ws", "--cover", "image-logo.png", "--background", "#1d1b2e" })
	local group = store.load(dir).nodes[1]
	assert.eq(group.data.cover, "image-logo.png")
	assert.eq(group.data.background, "#1d1b2e")
	assert.throws(function()
		run({ "set", "pub", "--background", "#1d1b2e" })
	end)
	run({ "set", "ws", "--background", "" })
	assert.eq(store.load(dir).nodes[1].data.background, nil)
end)

test.case("set attaches a GitHub issue from a URL and fills in an empty repository", function(assert)
	local dir, run = testing.createHarness("attach-issue")
	assert.strContains(
		run({ "set", "pub", "--ref", "https://github.com/Roblox/avatar/issues/3" }),
		"Updated pub · Publish v2.6.0"
	)
	local item = store.load(dir).nodes[3]
	assert.eq(item.data.repo, "Roblox/avatar")
	assert.eq(item.data.itemKind, "placeholder")
	assert.neq(findRef(item, "issue", "Roblox/avatar#3"), nil)
end)

test.case("set keeps the repository an item already has when a ref names another", function(assert)
	local dir, run = testing.createHarness("attach-keeps-repo")
	run({ "set", "ci", "--ref", "https://github.com/Roblox/avatar/issues/3" })
	local item = store.load(dir).nodes[2]
	assert.eq(item.data.repo, "flipbook-labs/flipbook")
	assert.neq(findRef(item, "issue", "Roblox/avatar#3"), nil)
end)

test.case("add attaches a pull request URL as a pr card", function(assert)
	local dir, run = testing.createHarness("add-ref")
	assert.strContains(
		run({ "add", "Write", "notes", "--group", "ws", "--ref", "https://github.com/Roblox/avatar/pull/9" }),
		"Added write-notes"
	)
	local item = store.load(dir).nodes[4]
	assert.eq(item.data.repo, "Roblox/avatar")
	assert.eq(item.data.itemKind, "pr")
	assert.neq(findRef(item, "pull", "Roblox/avatar#9"), nil)
end)

test.case("set attaches Jira issues by source:key through a configured source", function(assert)
	local dir, run = testing.createHarness("attach-jira")
	run({
		"source",
		"add",
		"jira",
		"--command",
		[[ ["acli","jira","workitem","search"] ]],
		"--browse",
		"https://jira.example.com/browse/",
	})
	run({ "set", "pub", "--ref", "jira:ABC-12" })
	run({ "set", "ci", "--ref", "https://jira.example.com/browse/ABC-13" })
	local nodes = store.load(dir).nodes
	local attached = findRef(nodes[3], "issue", "ABC-12")
	assert.eq(attached and attached.url, "https://jira.example.com/browse/ABC-12")
	local retitled = findRef(nodes[2], "issue", "ABC-13")
	assert.eq(retitled and retitled.source, "jira")
	assert.eq(nodes[3].data.repo, nil)
end)

test.case("a ref that cannot be resolved writes nothing", function(assert)
	local dir, run = testing.createHarness("attach-invalid")
	local before = store.load(dir).revision
	assert.throwsWith(
		"no source recognizes https://git.example.org/a/b/pull/1; add its GitHub or Jira source first, or use source:key",
		function()
			run({ "set", "pub", "--ref", "https://git.example.org/a/b/pull/1" })
		end
	)
	assert.throwsWith('no source with id "missing"', function()
		run({ "add", "Write", "notes", "--ref", "missing:ABC-1" })
	end)
	assert.eq(store.load(dir).revision, before)
	assert.eq(#store.load(dir).nodes, 3)
end)

test.case("set rejects item-only fields and refs on groups", function(assert)
	local dir, run = testing.createHarness("set-groups")
	assert.throwsWith("groups only take a label, blurb, arrange, cover, and background", function()
		run({ "set", "ws", "--note", "Remember" })
	end)
	assert.throwsWith("groups don't take refs; attach it to an item", function()
		run({ "set", "ws", "--ref", "https://github.com/Roblox/avatar/issues/3" })
	end)
	assert.throwsWith("groups only take a label, blurb, arrange, cover, and background", function()
		run({ "set", "ws", "--status", "done" })
	end)
	assert.throwsWith('"pub" is an item; only groups take a blurb', function()
		run({ "set", "pub", "--blurb", "Not for items" })
	end)
	assert.eq(store.load(dir).nodes[1].data.blurb, nil)
end)

test.case("repo and pr still attach a pull request as deprecated aliases", function(assert)
	local dir, run = testing.createHarness("deprecated-pr")
	run({ "set", "pub", "--repo", "Roblox/avatar", "--pr", "4" })
	local item = store.load(dir).nodes[3]
	assert.eq(item.data.itemKind, "pr")
	assert.neq(findRef(item, "pull", "Roblox/avatar#4"), nil)
	assert.strContains(run({ "set", "--help" }), "Deprecated")
	assert.strContains(run({ "set", "--help" }), "--ref")
	assert.strContains(run({ "add", "--help" }), "--ref")
end)

test.case("sync attaches a new pull request to the card its branch was recorded on", function(assert)
	local dir, run = testing.createHarness("attach-branch")
	run({ "set", "pub", "--ref", "branch:flipbook-labs/flipbook@feature/a" })
	local text = run({ "sync" }, function(argv)
		if argv[5]:find("pullRequests", 1, true) then
			return testing.result(
				true,
				[[{"data":{"viewer":{"login":"vocksel","pullRequests":{"nodes":[{"number":670,"title":"Add release health dashboard","url":"u670","state":"OPEN","isDraft":false,"headRefName":"feature/a","author":{"login":"vocksel"},"updatedAt":"2026-10-04T18:00:00Z","additions":80,"deletions":4,"repository":{"name":"flipbook","owner":{"login":"flipbook-labs"}}}]}}}}]]
			)
		elseif argv[5]:find("search(", 1, true) then
			return testing.result(true, [[{"data":{"search":{"nodes":[]}}}]])
		end

		return testing.result(true, [[{"data":{"p1":{"pullRequest":null}}}]])
	end)

	assert.strContains(text, "attached flipbook-labs/flipbook#670 to pub")
	local item = store.load(dir).nodes[3]
	assert.eq((findRef(item, "pull") :: any).key, "flipbook-labs/flipbook#670")
	assert.strContains(run({ "matches" }), "No unplaced pull requests.")
end)

test.case("group add wraps items, and a bare group still means add", function(assert)
	local dir, run = testing.createHarness("group-add")
	assert.strContains(run({ "group", "add", "Things", "to", "remove", "--items", "ci" }), "Grouped into")
	assert.strContains(run({ "group", "Ship", "it", "--items", "pub" }), "Grouped into")
	local labels: { [string]: boolean } = {}

	for _, item in store.load(dir).nodes do
		labels[item.data.label :: string] = true
	end

	assert.eq(labels["Things to remove"], true)
	assert.eq(labels["Ship it"], true)
end)

test.case("group remove previews and removes a group with everything inside", function(assert)
	local dir, run = testing.createHarness("group-remove")
	run({ "add", "Outside", "--group", "ws" })
	run({ "group", "add", "Inner", "--items", "outside" })
	local before = store.load(dir).revision
	local preview = run({ "group", "remove", "ws", "--dry-run" })
	assert.strContains(preview, "Would remove 1 group and 4 things inside")
	assert.strContains(preview, "    pub · Publish v2.6.0")
	assert.eq(store.load(dir).revision, before)

	assert.throwsWith('"pub" is an item, not a group', function()
		run({ "group", "remove", "pub" })
	end)

	run({ "group", "remove", "ws" })
	local doc = store.load(dir)
	assert.eq(#doc.nodes, 0)
	assert.eq(#doc.links, 0)
end)

test.case("remove still points groups at group remove", function(assert)
	local _, run = testing.createHarness("remove-group-hint")
	assert.throwsWith('"ws" is a group; use ungroup or group remove instead', function()
		run({ "remove", "ws" })
	end)
end)

test.case("ref remove takes a ref off by its key or URL", function(assert)
	local dir, run = testing.createHarness("ref-remove")
	run({ "set", "ci", "--ref", "https://github.com/Roblox/avatar/issues/3" })
	assert.eq(run({ "ref", "remove", "ci", "FLIPBOOK-LABS/flipbook#658" }), "Updated ci · Report release health")
	local item = store.load(dir).nodes[2]
	assert.eq(findRef(item, "pull"), nil)
	assert.eq(item.data.itemKind, "placeholder")

	run({ "ref", "remove", "ci", "https://github.com/Roblox/avatar/issues/3" })
	assert.eq(store.load(dir).nodes[2].data.refs, nil)

	assert.throwsWith('"ci" has no ref Roblox/avatar#3', function()
		run({ "ref", "remove", "ci", "Roblox/avatar#3" })
	end)
	assert.throwsWith("groups don't take refs", function()
		run({ "ref", "remove", "ws", "Roblox/avatar#3" })
	end)
end)

test.case("--version prints the version and build commit the MCP server reports", function(assert)
	local _, run = testing.createHarness("version")
	assert.eq(run({ "--version" }), `orion {getVersion()}`)
end)
