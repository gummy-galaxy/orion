local checkOptions = require("@root/adapters/checkOptions")
local getOne = require("@root/adapters/getOne")
local parseCommand = require("@root/adapters/parseCommand")
local types = require("@root/types")

type Source = types.Source

local function createSource(options: { [string]: { string } }): Source
	checkOptions("hop", options, { command = true })
	local command = getOne(options, "command")
	local argv = if command then parseCommand(command) else { "hop" }
	assert((argv[1] == "hop" or argv[1]:match("/hop$")) and #argv == 1, "hop command must name the hop executable")

	return { id = getOne(options, "id") or "hop", kind = "hop", command = argv }
end

return createSource
