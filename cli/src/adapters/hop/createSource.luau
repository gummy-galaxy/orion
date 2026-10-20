local checkOptions = require("@root/adapters/checkOptions")
local getOne = require("@root/adapters/getOne")
local parseCommand = require("@root/adapters/parseCommand")
local types = require("@root/types")

type Source = types.Source

-- The command is nil when it's left out, since hop runs `hop` from the PATH by default.
local function createSource(options: { [string]: { string } }): (Source, { string }?)
	checkOptions("hop", options, { command = true })
	local command = getOne(options, "command")
	local argv = if command then parseCommand(command) else nil
	assert(
		not argv or ((argv[1] == "hop" or argv[1]:match("/hop$")) and #argv == 1),
		"hop command must name the hop executable"
	)

	return { id = getOne(options, "id") or "hop", kind = "hop" }, argv
end

return createSource
