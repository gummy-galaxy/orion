local fs = require("@std/fs")
local path = require("@std/path")
local test = require("@std/test")

local pruneBackups = require("@root/store/pruneBackups")
local testing = require("@root/testing")

test.case("pruning keeps recent backups and one newest backup per UTC day", function(assert)
	local dir = testing.directory("prune")
	local folder = path.join(dir, "backups")
	fs.createDirectory(folder, { makeParents = true })
	local names = {
		"orion-r1-20261004T110000Z.json",
		"orion-r2-20261003T130000Z.json",
		"orion-r9-20261003T120000Z.json",
		"orion-r3-20261003T100000Z.json",
		"orion-r4-20261002T230000Z.json",
		"orion-r5-20261002T010000Z.json",
		"orion-r6-20260905T230000Z.json",
		"orion-r7-20260905T010000Z.json",
		"orion-r8-20260904T230000Z.json",
	}

	for _, name in names do
		fs.writeStringToFile(path.join(folder, name), name)
	end

	fs.writeStringToFile(path.join(folder, "keep-me.json"), "unrelated")
	fs.writeStringToFile(path.join(folder, "orion-r9-20261002T010000Z.json.tmp"), "unrelated")
	fs.createDirectory(path.join(folder, "orion-r10-20260904T010000Z.json"))
	pruneBackups(dir, 1791115200)

	for index, name in names do
		assert.eq(
			fs.exists(path.join(folder, name)),
			index == 1 or index == 2 or index == 3 or index == 5 or index == 7
		)
	end

	assert.eq(fs.exists(path.join(folder, "keep-me.json")), true)
	assert.eq(fs.exists(path.join(folder, "orion-r9-20261002T010000Z.json.tmp")), true)
	assert.eq(fs.exists(path.join(folder, "orion-r10-20260904T010000Z.json")), true)
end)
