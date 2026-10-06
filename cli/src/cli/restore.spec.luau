local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")
local test = require("@std/test")

local store = require("@root/store")
local testing = require("@root/testing")

test.case("restore takes the newest matching backup and backs up the current revision", function(assert)
	local dir, run = testing.harness("restore")
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
	local dir, run = testing.harness("missing-backup")
	assert.throwsWith("no backup for revision 9", function()
		run({ "restore", "9" })
	end)
	assert.eq(store.load(dir).revision, 0)
end)
