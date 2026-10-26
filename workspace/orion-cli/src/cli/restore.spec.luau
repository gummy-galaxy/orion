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

test.case("restore takes the newest matching backup and backs up the current revision", function(assert)
	local dir, run = testing.createHarness("restore")
	local folder = path.join(dir, "backups")
	fs.createDirectory(folder)
	local older = decodeDoc([[{"version":2,"revision":7,"settings":{},"nodes":[],"links":[]}]])
	local newest = decodeDoc(
		[[{"version":2,"revision":7,"settings":{"future":"kept"},"nodes":[{"id":"saved","type":"task","position":{"x":1,"y":2},"data":{"label":"Saved","status":"todo"}}],"links":[{"id":"saved>saved","from":"saved","to":"saved","kind":"related"}],"github":{"viewer":"saved"}}]]
	)
	fs.writeStringToFile(path.join(folder, "orion-r7-20261001T000000Z.json"), encodeDoc(older))
	fs.writeStringToFile(path.join(folder, "orion-r7-20261002T000000Z.json"), encodeDoc(newest))
	assert.strContains(run({ "backup", "restore", "7" }), "as revision 1")
	local restored = loadDoc(dir)
	assert.eq(restored.revision, 1)
	assert.eq(restored.nodes[1].id, "saved")
	assert.eq(restored.links[1].kind, "related")
	assert.eq(restored.version, 3)
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

test.case("restore changes only the selected workspace", function(assert)
	local root, run = testing.createHarness("workspace-restore")
	run({ "canvas", "create", "roblox" })
	local roblox = getWorkspaceDir(root, "roblox")
	runTransaction(roblox, function(doc)
		doc.raw = json.object({ settings = json.object({ theme = "changed" }) })
	end)

	assert.eq(loadDoc(roblox).revision, 1)
	assert.strContains(run({ "backup", "restore", "0", "--canvas", "roblox" }), "as revision 2")
	local raw = loadDoc(roblox).raw
	local settings = if raw then json.asObject(raw.settings) else nil
	assert.eq(settings and settings.theme, nil)
	assert.eq(loadDoc(root).revision, 0)
	assert.eq(#getBackups(root), 0)
	assert.eq(#getBackups(roblox), 2)
end)

test.case("restore reports a missing revision without changing data", function(assert)
	local dir, run = testing.createHarness("missing-backup")
	assert.throwsWith("no backup for revision 9", function()
		run({ "backup", "restore", "9" })
	end)

	assert.eq(loadDoc(dir).revision, 0)
end)
