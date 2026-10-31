local getClaudeDir = require("@root/adapters/claude/getClaudeDir")
local types = require("@root/types")

type Source = types.Source

-- Each running Claude Code process rewrites its record in `sessions/` when it
-- turns busy or idle, so that folder changes whenever a session's state does.
local function getWatchPaths(source: Source): { string }
	return { `{getClaudeDir(source)}/sessions` }
end

return getWatchPaths
