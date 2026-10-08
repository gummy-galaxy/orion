local test = require("@std/test")

local getExecutableName = require("@root/platform/getExecutableName")

test.case("Windows executables end in .exe", function(assert)
	assert.eq(getExecutableName("windows", "orion"), "orion.exe")
	assert.eq(getExecutableName("macos", "orion"), "orion")
	assert.eq(getExecutableName("linux", "orion"), "orion")
end)
