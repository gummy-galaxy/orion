local process = require("@std/process")

local types = require("@root/types")

type Source = types.Source

-- Claude Code's data folder for a source: its --dir, then CLAUDE_CONFIG_DIR, then ~/.claude.
local function getClaudeDir(source: Source): string
	return source.dir or process.env.CLAUDE_CONFIG_DIR or `{process.homedir()}/.claude`
end

return getClaudeDir
