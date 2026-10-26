local path = require("@std/path")
local system = require("@std/system")
local test = require("@std/test")

local getDataDir = require("@root/platform/getDataDir")

-- An absolute root on the platform running the spec, since getDataDir checks
-- environment paths with the host's rules.
local ROOT = if system.win32 then "C:/" else "/"

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
		tostring(getDataDir("linux", "/home/sam", { XDG_DATA_HOME = ROOT .. "data" })),
		tostring(path.join(ROOT .. "data", "orion"))
	)
	assert.eq(
		tostring(getDataDir("linux", "/home/sam", { XDG_DATA_HOME = "relative" })),
		tostring(path.join("/home/sam", ".local", "share", "orion"))
	)
	assert.eq(
		tostring(getDataDir("windows", "/Users/sam", { APPDATA = ROOT .. "Roaming" })),
		tostring(path.join(ROOT .. "Roaming", "Orion"))
	)
	assert.eq(
		tostring(getDataDir("windows", "/Users/sam", {})),
		tostring(path.join("/Users/sam", "AppData", "Roaming", "Orion"))
	)
	assert.eq(
		tostring(getDataDir("windows", "/Users/sam", { APPDATA = "" })),
		tostring(path.join("/Users/sam", "AppData", "Roaming", "Orion"))
	)
end)
