local path = require("@std/path")
local test = require("@std/test")

local getWorkspaceDir = require("@root/store/getWorkspaceDir")

test.case("the default workspace is the data root and the rest live under canvases", function(assert)
	assert.eq(getWorkspaceDir("/data", "default"), "/data")
	assert.eq(getWorkspaceDir("/data", "work"), tostring(path.join("/data", "canvases", "work")))
	assert.throwsWith("invalid canvas name: ../up", function()
		getWorkspaceDir("/data", "../up")
	end)
end)
