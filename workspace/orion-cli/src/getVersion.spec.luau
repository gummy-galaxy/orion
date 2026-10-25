local test = require("@std/test")

local buildInfo = require("@root/buildInfo")
local getVersion = require("@root/getVersion")

test.case("getVersion joins the package version and build commit", function(assert)
	local version = getVersion()

	assert.strContains(version, buildInfo.version)
	assert.strContains(version, `+{buildInfo.commit}`)
end)
