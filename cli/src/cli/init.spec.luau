local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")
local test = require("@std/test")

local cli = require("@root/cli")
local refs = require("@root/refs")
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
	local environment = ""
	local function run(args: { string }, runner: any?)
		table.clear(output)
		cli.execute(args, {
			dataDir = dir,
			workspace = environment,
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
	local function setWorkspace(name: string)
		environment = name
	end
	return dir, run, setWorkspace
end

test.case("ready lists startable work, most unblocking first", function(assert)
	local _, run = harness("ready")
	local text = run({ "ready" })
	assert.strContains(text, "ci")
	assert.strContains(text, "unblocks 1")
	assert.strNotContains(text, "pub")
end)

test.case("backups lists newest first with revision, time, and size", function(assert)
	local dir, run = harness("backups")
	local folder = path.join(dir, "backups")
	fs.createDirectory(folder)
	fs.writeStringToFile(path.join(folder, "orion-r2-20261002T010000Z.json"), "old")
	fs.writeStringToFile(path.join(folder, "orion-r1-20261003T010000Z.json"), "newer")
	local values = json.asArray(json.deserialize(run({ "backups", "--json" })) :: json.Value)
	local first = if values then json.asObject(values[1]) else nil
	assert.eq(values and #values, 2)
	assert.eq(first and first.revision, 1)
	assert.eq(first and first.time, "20261003T010000Z")
	assert.eq(first and first.size, 5)
	assert.strContains(run({ "backups" }), "r1  20261003T010000Z  5 bytes")
end)

test.case("restore takes the newest matching backup and backs up the current revision", function(assert)
	local dir, run = harness("restore")
	local folder = path.join(dir, "backups")
	fs.createDirectory(folder)
	local older = store.decode([[{"version":1,"revision":7,"settings":{"githubOwner":"older"},"nodes":[],"links":[]}]])
	local newest = store.decode(
		[[{"version":1,"revision":7,"settings":{"githubOwner":"restored","future":"kept"},"nodes":[{"id":"saved","type":"task","position":{"x":1,"y":2},"data":{"label":"Saved","status":"todo"}}],"links":[{"id":"saved>saved","from":"saved","to":"saved","kind":"related"}],"github":{"viewer":"saved"}}]]
	)
	fs.writeStringToFile(path.join(folder, "orion-r7-20261001T000000Z.json"), store.encode(older))
	fs.writeStringToFile(path.join(folder, "orion-r7-20261002T000000Z.json"), store.encode(newest))
	assert.strContains(run({ "restore", "7" }), "as revision 1")
	local restored = store.load(dir)
	assert.eq(restored.revision, 1)
	assert.eq(restored.nodes[1].id, "saved")
	assert.eq(restored.links[1].kind, "related")
	assert.eq(restored.settings.githubOwner, "restored")
	assert.eq(restored.github and restored.github.viewer, "saved")
	local settings = if restored.raw then json.asObject(restored.raw.settings) else nil
	assert.eq(settings and settings.future, "kept")
	local currentBackup: store.Backup?
	for _, backup in store.backups(dir) do
		if backup.revision == 0 then
			currentBackup = backup
		end
	end
	assert.eq(currentBackup ~= nil, true)
	assert.eq(store.decode(fs.readFileToString((currentBackup :: store.Backup).file)).nodes[1].id, "ws")
end)

test.case("restore reports a missing revision without changing data", function(assert)
	local dir, run = harness("missing-backup")
	assert.throwsWith("no backup for revision 9", function()
		run({ "restore", "9" })
	end)
	assert.eq(store.load(dir).revision, 0)
end)

test.case("workspace create and list use a temporary data root", function(assert)
	local root, run = harness("workspace-create")
	local initial = json.asObject(json.deserialize(run({ "workspace", "list", "--json" })) :: json.Value)
	assert.eq(initial and initial.active, "default")
	assert.eq(initial and #(json.asArray(initial.workspaces) or {}), 1)
	run({ "workspace", "create", "roblox", "--label", "Roblox", "--owner", "Roblox" })
	local dir = tostring(path.join(root, "workspaces", "roblox"))
	local doc = store.load(dir)
	assert.eq(doc.version, 1)
	assert.eq(doc.revision, 0)
	assert.eq(doc.settings.githubOwner, "Roblox")
	assert.eq(#doc.nodes, 0)
	assert.eq(#doc.links, 0)
	local listed = json.asObject(json.deserialize(run({ "workspace", "list", "--json" })) :: json.Value)
	local entries = if listed then json.asArray(listed.workspaces) else nil
	assert.eq(listed and listed.active, "default")
	assert.eq(entries and #entries, 2)
	local second = if entries then json.asObject(entries[2]) else nil
	assert.eq(second and second.label, "Roblox")
	assert.eq(run({ "path", "--workspace", "roblox" }), dir)
	assert.eq(run({ "--workspace", "roblox", "path" }), dir)
	assert.eq(run({ "path" }), root)
	assert.throwsWith("workspace already exists: roblox", function()
		run({ "workspace", "create", "roblox" })
	end)
	assert.throwsWith("invalid workspace name: Bad/Name", function()
		run({ "workspace", "create", "Bad/Name" })
	end)
end)

test.case("sources belong to the selected workspace", function(assert)
	local root, run = harness("workspace-sources")
	run({ "workspace", "create", "roblox" })
	run({ "workspace", "use", "roblox" })
	run({ "source", "add", "github", "--host", "github.com", "--owner", "Roblox" })
	run({ "--workspace", "default", "source", "add", "hop" })
	local roblox = store.load(tostring(path.join(root, "workspaces", "roblox")))
	assert.eq(#roblox.settings.sources, 1)
	assert.eq(roblox.settings.sources[1].kind, "github")
	assert.eq(store.load(root).settings.sources[1].kind, "hop")
end)

test.case("workspace selection follows option, environment, manifest, default", function(assert)
	local root, run, setWorkspace = harness("workspace-use")
	assert.eq(run({ "workspace", "current" }), "default")
	run({ "workspace", "create", "roblox" })
	run({ "workspace", "create", "docs" })
	run({ "workspace", "use", "roblox" })
	assert.eq(run({ "workspace", "current" }), "roblox")
	assert.eq(run({ "path" }), tostring(path.join(root, "workspaces", "roblox")))
	setWorkspace("docs")
	assert.eq(run({ "workspace", "current" }), "docs")
	local listed = json.asObject(json.deserialize(run({ "workspace", "list", "--json" })) :: json.Value)
	assert.eq(listed and listed.active, "docs")
	assert.eq(run({ "path", "--workspace", "roblox" }), tostring(path.join(root, "workspaces", "roblox")))
	local overridden =
		json.asObject(json.deserialize(run({ "workspace", "list", "--json", "--workspace", "roblox" })) :: json.Value)
	assert.eq(overridden and overridden.active, "roblox")
	setWorkspace("")
	assert.throwsWith("unknown workspace: missing", function()
		run({ "workspace", "use", "missing" })
	end)
	assert.throwsWith("unknown workspace: missing", function()
		run({ "path", "--workspace", "missing" })
	end)
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

test.case("set arranges a group and show reports it", function(assert)
	local dir, run = harness("arrange")
	local shown = json.asObject(json.deserialize(run({ "show", "ws", "--json" })) :: json.Value)
	assert.eq(shown and shown.arrange, "auto")
	run({ "set", "ws", "--arrange", "grid", "--columns", "4" })
	shown = json.asObject(json.deserialize(run({ "show", "ws", "--json" })) :: json.Value)
	assert.eq(shown and shown.arrange, "grid")
	assert.eq(shown and shown.columns, 4)
	assert.strContains(run({ "show", "ws" }), "arrange  grid, 4 columns")
	assert.eq(store.load(dir).nodes[1].data.layout, "refit")
	assert.throwsWith("columns must be a number", function()
		run({ "set", "ws", "--columns", "many" })
	end)
	assert.throwsWith("only groups take arrange and columns", function()
		run({ "set", "pub", "--arrange", "custom" })
	end)
	local item = json.asObject(json.deserialize(run({ "show", "pub", "--json" })) :: json.Value)
	assert.eq(item and item.arrange, nil)
end)

test.case("sync writes GitHub state through the command runner", function(assert)
	local dir, run = harness("sync")
	local text = run({ "sync" }, function(argv)
		if argv[5]:find("pullRequests", 1, true) then
			return testing.result(true, [[{"data":{"viewer":{"login":"vocksel","pullRequests":{"nodes":[]}}}}]])
		end
		return testing.result(
			true,
			[[{"data":{"p1":{"pullRequest":{"number":658,"title":"Report release health to PostHog","url":"u","state":"MERGED","isDraft":false,"reviewDecision":null,"reviewRequests":{"totalCount":0},"author":{"login":"vocksel"},"updatedAt":"2026-10-04T01:00:00Z","additions":120,"deletions":30,"commits":{"nodes":[{"commit":{"statusCheckRollup":{"state":"SUCCESS"}}}]}}}}}]]
		)
	end)
	assert.strContains(text, "ci: active → done")
	local item = store.load(dir).nodes[2]
	assert.eq(item.data.status, "done")
	local driver = refs.driver(item)
	local recorded = if driver then json.asObject(driver.state) else nil
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

test.case("sync stores unplaced authored pulls without adding cards", function(assert)
	local dir, run = harness("unplaced")
	local before = #store.load(dir).nodes
	run({ "sync" }, function(argv)
		if argv[5]:find("pullRequests", 1, true) then
			return testing.result(
				true,
				[[{"data":{"viewer":{"login":"vocksel","pullRequests":{"nodes":[{"number":670,"title":"Add release health dashboard","url":"u670","state":"OPEN","isDraft":false,"author":{"login":"vocksel"},"updatedAt":"2026-10-04T18:00:00Z","additions":80,"deletions":4,"repository":{"name":"flipbook","owner":{"login":"flipbook-labs"}}}]}}}}]]
			)
		end
		return testing.result(true, [[{"data":{"p1":{"pullRequest":null}}}]])
	end)
	local doc = store.load(dir)
	assert.eq(#doc.nodes, before)
	local top = doc.github
	local unplaced = if top then json.asArray(top.unplaced) else nil
	assert.eq(unplaced and #unplaced, 1)
	assert.strContains(run({ "matches" }), "flipbook#670")
end)
