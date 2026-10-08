local path = require("@std/path")
local test = require("@std/test")

local platformDirs = require("@root/platformDirs")

test.case("data folders follow each platform's convention", function(assert)
	assert.eq(
		platformDirs.dataDir("macos", "/Users/sam", {}),
		tostring(path.join("/Users/sam", "Library", "Application Support", "Orion"))
	)
	assert.eq(
		platformDirs.dataDir("linux", "/home/sam", {}),
		tostring(path.join("/home/sam", ".local", "share", "orion"))
	)
	assert.eq(
		platformDirs.dataDir("linux", "/home/sam", { XDG_DATA_HOME = "/data" }),
		tostring(path.join("/data", "orion"))
	)
	assert.eq(
		platformDirs.dataDir("linux", "/home/sam", { XDG_DATA_HOME = "relative" }),
		tostring(path.join("/home/sam", ".local", "share", "orion"))
	)
	assert.eq(
		platformDirs.dataDir("windows", "/Users/sam", { APPDATA = "/Roaming" }),
		tostring(path.join("/Roaming", "Orion"))
	)
	assert.eq(
		platformDirs.dataDir("windows", "/Users/sam", {}),
		tostring(path.join("/Users/sam", "AppData", "Roaming", "Orion"))
	)
	assert.eq(platformDirs.executableName("windows", "orion"), "orion.exe")
	assert.eq(platformDirs.executableName("macos", "orion"), "orion")
end)
