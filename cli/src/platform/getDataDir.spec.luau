local path = require("@std/path")
local test = require("@std/test")

local getDataDir = require("@root/platform/getDataDir")

test.case("data folders follow each platform's convention", function(assert)
	assert.eq(
		tostring(getDataDir("macos", "/Users/sam", {})),
		tostring(path.join("/Users/sam", "Library", "Application Support", "Orion"))
	)
	assert.eq(
		tostring(getDataDir("linux", "/home/sam", {})),
		tostring(path.join("/home/sam", ".local", "share", "orion"))
	)
	assert.eq(
		tostring(getDataDir("linux", "/home/sam", { XDG_DATA_HOME = "/data" })),
		tostring(path.join("/data", "orion"))
	)
	assert.eq(
		tostring(getDataDir("linux", "/home/sam", { XDG_DATA_HOME = "relative" })),
		tostring(path.join("/home/sam", ".local", "share", "orion"))
	)
	assert.eq(
		tostring(getDataDir("windows", "/Users/sam", { APPDATA = "/Roaming" })),
		tostring(path.join("/Roaming", "Orion"))
	)
	assert.eq(
		tostring(getDataDir("windows", "/Users/sam", {})),
		tostring(path.join("/Users/sam", "AppData", "Roaming", "Orion"))
	)
end)
