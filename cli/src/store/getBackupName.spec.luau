local test = require("@std/test")

local getBackupName = require("@root/store/getBackupName")

test.case("backup names use the replaced revision and UTC second", function(assert)
	assert.eq(getBackupName(42, 1791115200), "orion-r42-20261004T120000Z.json")
end)
