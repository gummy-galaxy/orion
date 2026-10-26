local fs = require("@std/fs")
local path = require("@std/path")
local test = require("@std/test")

local pruneBackups = require("@root/store/pruneBackups")
local readRevisions = require("@root/store/readRevisions")
local testing = require("@root/testing")

local NOW = 1791115200
local MINUTE = 60
local DAY = 24 * 60 * MINUTE

local function backupName(revision: number, time: number): string
	return `orion-r{revision}-{os.date("!%Y%m%dT%H%M%SZ", time)}.json`
end

test.case("pruning keeps the newest 200 backups and one newest backup per UTC day", function(assert)
	local dir = testing.directory("prune")
	local folder = path.join(dir, "backups")
	fs.createDirectory(folder, { makeParents = true })
	local expected: { [string]: boolean } = {}
	local log: { string } = {}

	-- 205 backups a minute apart, newest first, so the last five fall past the
	-- newest 200 on a day that already has its newest.
	for revision = 1, 205 do
		local name = backupName(1000 - revision, NOW - revision * MINUTE)
		fs.writeStringToFile(path.join(folder, name), name)
		expected[name] = revision <= 200
		table.insert(log, `\{"revision":{1000 - revision},"time":"t","by":"app"}\n`)
	end

	-- Older days keep only their newest backup, and only within 30 days.
	local older = {
		{ name = backupName(10, NOW - 2 * DAY), keep = true },
		{ name = backupName(9, NOW - 2 * DAY - MINUTE), keep = false },
		{ name = backupName(8, NOW - 28 * DAY), keep = true },
		{ name = backupName(7, NOW - 31 * DAY), keep = false },
	}

	for _, backup in older do
		fs.writeStringToFile(path.join(folder, backup.name), backup.name)
		expected[backup.name] = backup.keep
	end

	table.insert(log, `\{"revision":9,"time":"t","by":"app"}\n`)
	table.insert(log, `\{"revision":10,"time":"t","by":"cli","command":"link create"}\n`)
	table.insert(log, `\{"revision":1000,"time":"t","by":"app"}\n`)
	fs.writeStringToFile(path.join(folder, "revisions.jsonl"), table.concat(log))
	fs.writeStringToFile(path.join(folder, "keep-me.json"), "unrelated")
	pruneBackups(dir, NOW)

	for name, keep in expected do
		assert.eq(`{name} {fs.exists(path.join(folder, name))}`, `{name} {keep}`)
	end

	assert.eq(fs.exists(path.join(folder, "keep-me.json")), true)
	local revisions = readRevisions(dir)
	assert.eq(revisions[1000] and revisions[1000].by, "app")
	assert.eq(revisions[999] ~= nil, true)
	assert.eq(revisions[800] ~= nil, true)
	assert.eq(revisions[799], nil)
	assert.eq(revisions[10] and revisions[10].command, "link create")
	assert.eq(revisions[9], nil)
end)
