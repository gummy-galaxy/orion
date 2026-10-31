local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")
local test = require("@std/test")

local decodeDoc = require("@root/store/decodeDoc")
local encodeDoc = require("@root/store/encodeDoc")
local getBackups = require("@root/store/getBackups")
local getWorkspaceDir = require("@root/store/getWorkspaceDir")
local loadDoc = require("@root/store/loadDoc")
local runTransaction = require("@root/store/runTransaction")
local storeTypes = require("@root/store/types")
local testing = require("@root/testing")

type Backup = storeTypes.Backup

test.case("history set takes the newest matching backup and backs up the current revision", function(assert)
	local dir, run = testing.createHarness("restore")
	local folder = path.join(dir, "backups")
	fs.createDirectory(folder)
	local older = decodeDoc([[{"version":2,"revision":7,"settings":{},"nodes":[],"links":[]}]])
	local newest = decodeDoc(
		[[{"version":2,"revision":7,"settings":{"future":"kept"},"nodes":[{"id":"saved","type":"task",]]
			.. [["position":{"x":1,"y":2},"data":{"label":"Saved","status":"todo"}}],]]
			.. [["links":[{"id":"saved>saved","from":"saved","to":"saved","kind":"related"}],]]
			.. [["github":{"viewer":"saved"}}]]
	)
	fs.writeStringToFile(path.join(folder, "orion-r7-20261001T000000Z.json"), encodeDoc(older))
	fs.writeStringToFile(path.join(folder, "orion-r7-20261002T000000Z.json"), encodeDoc(newest))
	assert.strContains(run({ "history", "set", "7" }), "as revision 1")
	local restored = loadDoc(dir)
	assert.eq(restored.revision, 1)
	assert.eq(restored.nodes[1].id, "saved")
	assert.eq(restored.links[1].kind, "related")
	assert.eq(restored.version, 2)
	assert.eq(restored.github and restored.github.viewer, "saved")
	local settings = if restored.raw then json.asObject(restored.raw.settings) else nil
	assert.eq(settings and settings.future, "kept")
	local currentBackup: Backup?

	for _, backup in getBackups(dir) do
		if backup.revision == 0 then
			currentBackup = backup
		end
	end

	assert.eq(currentBackup ~= nil, true)
	assert.eq(decodeDoc(fs.readFileToString((currentBackup :: Backup).file)).nodes[1].id, "ws")
end)

test.case("history set changes only the selected canvas", function(assert)
	local root, run = testing.createHarness("workspace-restore")
	run({ "canvas", "create", "roblox" })
	local roblox = getWorkspaceDir(root, "roblox")
	runTransaction(roblox, function(doc)
		doc.raw = json.object({ settings = json.object({ theme = "changed" }) })
	end)

	assert.eq(loadDoc(roblox).revision, 1)
	assert.strContains(run({ "history", "set", "0", "--canvas", "roblox" }), "as revision 2")
	local raw = loadDoc(roblox).raw
	local settings = if raw then json.asObject(raw.settings) else nil
	assert.eq(settings and settings.theme, nil)
	assert.eq(loadDoc(root).revision, 0)
	assert.eq(#getBackups(root), 0)
	assert.eq(#getBackups(roblox), 2)
end)

test.case("history set refuses a revision with no backup and the current one", function(assert)
	local dir, run = testing.createHarness("missing-backup")
	assert.throwsWith("no saved revision 9; orion history list shows the ones you can jump to", function()
		run({ "history", "set", "9" })
	end)
	assert.throwsWith("the canvas is already at revision 0", function()
		run({ "history", "set", "0" })
	end)

	assert.eq(loadDoc(dir).revision, 0)
end)

test.case("history set jumps back and forth, and a dry run lists what would change", function(assert)
	local dir, run = testing.createHarness("history-jump")
	run({ "link", "create", "pub", "ci", "--related", "--label", "Notes" })
	run({ "card", "set", "pub", "--ref", "https://github.com/flipbook-labs/flipbook/pull/12" })
	local preview = run({ "history", "set", "0", "--dry-run" })
	assert.strContains(preview, "Would set the canvas to revision 0 at revision 2")
	assert.strContains(preview, '  - link pub → ci (related) "Notes"')
	assert.strContains(preview, "  - ref flipbook-labs/flipbook#12 on pub")
	assert.eq(loadDoc(dir).revision, 2)

	assert.throwsWith("revision changed: expected 1, current 2", function()
		run({ "history", "set", "0", "--if-revision", "1" })
	end)

	local value = json.asObject(json.deserialize(run({ "history", "set", "0", "--json" })) :: json.Value) :: json.Object
	assert.eq(value.revision, 3)
	assert.eq(value.target, 0)
	assert.eq(#loadDoc(dir).links, 1)
	assert.eq(loadDoc(dir).links[1].from, "ci")

	assert.strContains(run({ "history", "set", "2" }), "Set the canvas to revision 2 as revision 4")
	local doc = loadDoc(dir)
	assert.eq(#doc.links, 2)
	assert.strContains(run({ "node", "show", "pub" }), "flipbook-labs/flipbook#12")
end)

test.case("backup restore still works under its old name", function(assert)
	local dir, run = testing.createHarness("backup-alias")
	run({ "note", "create", "Scratch", "--group", "ws" })
	assert.strContains(run({ "backup", "restore", "0" }), "Set the canvas to revision 0 as revision 2")
	assert.eq(#loadDoc(dir).nodes, 3)
end)
