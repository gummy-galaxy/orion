local path = require("@std/path")

local checkOptions = require("@root/adapters/checkOptions")
local getOne = require("@root/adapters/getOne")
local types = require("@root/types")

type Source = types.Source

-- Claude Code runs no program of its own choosing, so it never has a command.
local function createSource(options: { [string]: { string } }): (Source, { string }?)
	checkOptions("claude", options, { dir = true })
	local dir = getOne(options, "dir")
	assert(not dir or path.isAbsolute(dir), "--dir needs an absolute path")

	return { id = getOne(options, "id") or "claude", kind = "claude", dir = dir }, nil
end

return createSource
