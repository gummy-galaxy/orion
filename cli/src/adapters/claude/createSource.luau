local checkOptions = require("@root/adapters/checkOptions")
local getOne = require("@root/adapters/getOne")
local types = require("@root/types")

type Source = types.Source

-- Claude Code runs no program of its own choosing, so it never has a command.
local function createSource(options: { [string]: { string } }): (Source, { string }?)
	checkOptions("claude", options, { dir = true })
	local dir = getOne(options, "dir")
	assert(not dir or dir:sub(1, 1) == "/", "--dir needs an absolute path")

	return { id = getOne(options, "id") or "claude", kind = "claude", dir = dir }, nil
end

return createSource
