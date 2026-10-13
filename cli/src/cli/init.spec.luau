local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")
local test = require("@std/test")

local findRef = require("@root/refs/findRef")
local store = require("@root/store")
local testing = require("@root/testing")

test.case("ready lists startable work, most unblocking first", function(assert)
	local _, run = testing.createHarness("ready")
	local text = run({ "next" })
	assert.strContains(text, "ci")
	assert.strContains(text, "unblocks 1")
	assert.strNotContains(text, "pub")
end)

test.case("add, link, and done change the shared data", function(assert)
	local dir, run = testing.createHarness("edit")
	assert.strContains(
		run({ "card", "add", "Write", "release", "notes", "--group", "ws" }),
		"Added write-release-notes"
	)
	run({ "link", "add", "pub", "write-release-notes" })
	local shown =
		json.asObject(json.deserialize(run({ "node", "show", "write-release-notes", "--json" })) :: json.Value)
	assert.eq(shown and shown.status, "blocked")
	run({ "card", "done", "ci" })
	run({ "card", "done", "pub" })
	assert.eq(store.load(dir).revision, 4)
	assert.strContains(run({ "next" }), "write-release-notes")
end)

test.case("group parses comma-separated ids with spaces and empty entries", function(assert)
	local dir, run = testing.createHarness("group-items")
	run({ "group", "add", "Milestone", "--items", " ci, pub, , " })
	local doc = store.load(dir)
	assert.eq(doc.nodes[2].parentId, doc.nodes[3].parentId)
	assert.eq(doc.nodes[2].parentId == "ws", false)
end)

test.case("group set arranges a group and node show reports it", function(assert)
	local dir, run = testing.createHarness("arrange")
	local shown = json.asObject(json.deserialize(run({ "node", "show", "ws", "--json" })) :: json.Value)
	assert.eq(shown and shown.arrange, "auto")
	run({ "group", "set", "ws", "--arrange", "custom" })
	shown = json.asObject(json.deserialize(run({ "node", "show", "ws", "--json" })) :: json.Value)
	assert.eq(shown and shown.arrange, "custom")
	assert.strContains(run({ "node", "show", "ws" }), "arrange  custom")
	run({ "group", "set", "ws", "--arrange", "auto" })
	assert.eq(store.load(dir).nodes[1].data.layout, "refit")
	assert.throwsWith("Unknown argument: arrange", function()
		run({ "card", "set", "pub", "--arrange", "custom" })
	end)
	local item = json.asObject(json.deserialize(run({ "node", "show", "pub", "--json" })) :: json.Value)
	assert.eq(item and item.arrange, nil)
end)

test.case("set renames items and groups and reports the new labels", function(assert)
	local dir, run = testing.createHarness("set-label")
	assert.eq(run({ "card", "set", "pub", "--label", "New item name" }), "Updated pub · New item name")
	assert.eq(run({ "group", "set", "ws", "--label", "New group name" }), "Updated ws · New group name")
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

	assert.strContains(run({ "source", "matches" }), "flipbook#670")
	assert.strContains(run({ "source", "matches" }), "pub")
	local values = json.asArray(json.deserialize(run({ "source", "matches", "--json" })) :: json.Value)
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
	assert.strContains(run({ "source", "matches" }), "flipbook#670")
end)

test.case("set puts a cover and background on a group, and needs the cover image in the workspace", function(assert)
	local dir, run = testing.createHarness("set-group-style")
	assert.throws(function()
		run({ "group", "set", "ws", "--cover", "image-missing.png" })
	end)
	fs.createDirectory(path.join(dir, "assets"), { makeParents = true })
	fs.writeStringToFile(path.join(dir, "assets", "image-logo.png"), "bytes")
	run({ "group", "set", "ws", "--cover", "image-logo.png", "--background", "#1d1b2e" })
	local group = store.load(dir).nodes[1]
	assert.eq(group.data.cover, "image-logo.png")
	assert.eq(group.data.background, "#1d1b2e")
	assert.throws(function()
		run({ "card", "set", "pub", "--background", "#1d1b2e" })
	end)
	run({ "group", "set", "ws", "--background", "" })
	assert.eq(store.load(dir).nodes[1].data.background, nil)
end)

test.case("set attaches a GitHub issue from a URL and fills in an empty repository", function(assert)
	local dir, run = testing.createHarness("attach-issue")
	assert.strContains(
		run({ "card", "set", "pub", "--ref", "https://github.com/Roblox/avatar/issues/3" }),
		"Updated pub · Publish v2.6.0"
	)
	local item = store.load(dir).nodes[3]
	assert.eq(item.data.repo, "Roblox/avatar")
	assert.eq(item.data.itemKind, "placeholder")
	assert.neq(findRef(item, "issue", "Roblox/avatar#3"), nil)
end)

test.case("set keeps the repository an item already has when a ref names another", function(assert)
	local dir, run = testing.createHarness("attach-keeps-repo")
	run({ "card", "set", "ci", "--ref", "https://github.com/Roblox/avatar/issues/3" })
	local item = store.load(dir).nodes[2]
	assert.eq(item.data.repo, "flipbook-labs/flipbook")
	assert.neq(findRef(item, "issue", "Roblox/avatar#3"), nil)
end)

test.case("add attaches a pull request URL as a pr card", function(assert)
	local dir, run = testing.createHarness("add-ref")
	assert.strContains(
		run({ "card", "add", "Write", "notes", "--group", "ws", "--ref", "https://github.com/Roblox/avatar/pull/9" }),
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
	run({ "card", "set", "pub", "--ref", "jira:ABC-12" })
	run({ "card", "set", "ci", "--ref", "https://jira.example.com/browse/ABC-13" })
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
			run({ "card", "set", "pub", "--ref", "https://git.example.org/a/b/pull/1" })
		end
	)
	assert.throwsWith('no source with id "missing"', function()
		run({ "card", "add", "Write", "notes", "--ref", "missing:ABC-1" })
	end)
	assert.eq(store.load(dir).revision, before)
	assert.eq(#store.load(dir).nodes, 3)
end)

test.case("group set rejects item-only fields and card set rejects groups", function(assert)
	local dir, run = testing.createHarness("set-groups")
	assert.throwsWith("Unknown argument: note", function()
		run({ "group", "set", "ws", "--note", "Remember" })
	end)
	assert.throwsWith("Unknown argument: ref", function()
		run({ "group", "set", "ws", "--ref", "https://github.com/Roblox/avatar/issues/3" })
	end)
	assert.throwsWith('"ws" is a group; use orion group set', function()
		run({ "card", "set", "ws", "--status", "done" })
	end)
	assert.throwsWith('"ws" is a group; use orion group set', function()
		run({ "card", "set", "ws", "--ref", "https://github.com/Roblox/avatar/issues/3" })
	end)
	assert.throwsWith('"pub" is an item; use orion card set', function()
		run({ "group", "set", "pub", "--blurb", "Not for items" })
	end)
	assert.eq(store.load(dir).nodes[1].data.blurb, nil)
end)

test.case("repo and pr still attach a pull request as deprecated aliases", function(assert)
	local dir, run = testing.createHarness("deprecated-pr")
	run({ "card", "set", "pub", "--repo", "Roblox/avatar", "--pr", "4" })
	local item = store.load(dir).nodes[3]
	assert.eq(item.data.itemKind, "pr")
	assert.neq(findRef(item, "pull", "Roblox/avatar#4"), nil)
	assert.strContains(run({ "card", "set", "--help" }), "Deprecated")
	assert.strContains(run({ "card", "set", "--help" }), "--ref")
	assert.strContains(run({ "card", "add", "--help" }), "--ref")
end)

test.case("sync attaches a new pull request to the card its branch was recorded on", function(assert)
	local dir, run = testing.createHarness("attach-branch")
	run({ "card", "set", "pub", "--ref", "branch:flipbook-labs/flipbook@feature/a" })
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
	assert.strContains(run({ "source", "matches" }), "No unplaced pull requests.")
end)

test.case("group add wraps items, and the old bare group form is gone", function(assert)
	local dir, run = testing.createHarness("group-add")
	assert.strContains(run({ "group", "add", "Things", "to", "remove", "--items", "ci" }), "Grouped into")
	assert.strContains(run({ "group", "add", "Ship", "it", "--items", "pub" }), "Grouped into")
	assert.throwsWith("Unknown command: Ship", function()
		run({ "group", "Ship", "--items", "pub" })
	end)
	local labels: { [string]: boolean } = {}

	for _, item in store.load(dir).nodes do
		labels[item.data.label :: string] = true
	end

	assert.eq(labels["Things to remove"], true)
	assert.eq(labels["Ship it"], true)
end)

test.case("group remove previews and removes a group with everything inside", function(assert)
	local dir, run = testing.createHarness("group-remove")
	run({ "card", "add", "Outside", "--group", "ws" })
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

test.case("node remove still points groups at group ungroup or group remove", function(assert)
	local _, run = testing.createHarness("remove-group-hint")
	assert.throwsWith('"ws" is a group; use group ungroup or group remove instead', function()
		run({ "node", "remove", "ws" })
	end)
end)

test.case("ref remove takes a ref off by its key or URL", function(assert)
	local dir, run = testing.createHarness("ref-remove")
	run({ "card", "set", "ci", "--ref", "https://github.com/Roblox/avatar/issues/3" })
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

test.case("flat command names and --workspace are gone, and help uses the noun form", function(assert)
	local _, run = testing.createHarness("noun-names")
	assert.throwsWith("Unknown command: list", function()
		run({ "list" })
	end)
	assert.throwsWith("Unknown command: workspace", function()
		run({ "workspace", "list" })
	end)
	assert.throwsWith("Unknown argument: workspace", function()
		run({ "--workspace", "roblox", "card", "list" })
	end)
	assert.throwsWith("choose list, add, set, done, import", function()
		run({ "card" })
	end)
	assert.strContains(run({ "help", "card", "list" }), "orion card list")
	assert.strContains(run({ "help", "node", "query" }), "Fields: kind")
	assert.strContains(run({ "card", "--help" }), "import")
end)

test.case("node find matches labels, refs, and notes, label matches first", function(assert)
	local _, run = testing.createHarness("find-rank")
	run({ "card", "set", "pub", "--note", "Needs the release checklist" })
	local found = json.asObject(json.deserialize(run({ "node", "find", "release", "--json" })) :: json.Value)
	assert.eq(found and found.total, 3)
	local items = if found then json.asArray(found.items) or {} else {}
	assert.eq(json.asObject(items[1]) and json.asObject(items[1]).id, "ws")
	assert.eq(json.asObject(items[2]) and json.asObject(items[2]).id, "ci")
	assert.eq(json.asObject(items[3]) and json.asObject(items[3]).id, "pub")
	assert.strContains(run({ "node", "find", "flipbook-labs/flipbook#658" }), "ci")
	assert.strContains(run({ "node", "find", "release", "--limit", "1" }), "Showing 1 of 3 matches")
	assert.strContains(run({ "node", "find", "publish" }), "pub")
	assert.eq(run({ "node", "find", "nothing like this" }), "Nothing matches.")
	assert.throws(function()
		run({ "node", "find", "release", "--limit", "0" })
	end)
end)

test.case("node find --all-canvases searches every canvas", function(assert)
	local _, run, setWorkspace = testing.createHarness("find-canvases")
	run({ "canvas", "create", "other" })
	setWorkspace("other")
	run({ "card", "add", "Release", "notes" })
	setWorkspace("")
	assert.strNotContains(run({ "node", "find", "release" }), "other")
	local text = run({ "node", "find", "release", "--all-canvases" })
	assert.strContains(text, "other")
	local found =
		json.asObject(json.deserialize(run({ "node", "find", "release", "--all-canvases", "--json" })) :: json.Value)
	assert.eq(found and found.total, 3)
end)

test.case("selectors name an item by label, ref, or pr and must match exactly one", function(assert)
	local _, run = testing.createHarness("selectors")
	local function idOf(selector: string): any
		local shown = json.asObject(json.deserialize(run({ "node", "show", selector, "--json" })) :: json.Value)
		return shown and shown.id
	end
	assert.eq(idOf(`label:"Publish v2.6.0"`), "pub")
	assert.eq(idOf("label:'Report release health'"), "ci")
	assert.eq(idOf("ref:flipbook-labs/flipbook#658"), "ci")
	assert.eq(idOf("pr:658"), "ci")
	assert.eq(idOf("pub"), "pub")
	assert.throws(function()
		run({ "node", "show", `label:"Nothing like this"` })
	end)
	assert.throws(function()
		run({ "node", "show", "owner:orion" })
	end)
	run({ "card", "add", "Publish v2.6.0" })
	assert.throws(function()
		run({ "node", "show", `label:"Publish v2.6.0"` })
	end)
end)

test.case("selectors work in writes and report the ids they resolved to", function(assert)
	local dir, run = testing.createHarness("selector-writes")
	assert.eq(run({ "card", "set", `label:"Publish v2.6.0"`, "--label", "Ship v2.6.0" }), "Updated pub · Ship v2.6.0")
	assert.eq(run({ "card", "done", "ref:flipbook-labs/flipbook#658" }), "Done: ci · Report release health")
	assert.eq(run({ "link", "add", "ci", `label:"Ship v2.6.0"`, "--related" }), "ci and pub are related")
	assert.eq(run({ "node", "move", `label:"Ship v2.6.0"`, "--to", "ws" }), "Moved pub to ws")
	assert.eq(run({ "group", "set", `label:"Release"`, "--label", "Renamed" }), "Updated ws · Renamed")
	assert.eq(store.load(dir).nodes[1].data.label, "Renamed")
end)
