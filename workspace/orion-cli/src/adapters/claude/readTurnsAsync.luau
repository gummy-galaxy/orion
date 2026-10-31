local adapterTypes = require("@root/adapters/types")
local findTranscript = require("@root/adapters/claude/findTranscript")
local getClaudeDir = require("@root/adapters/claude/getClaudeDir")
local parseTranscript = require("@root/adapters/claude/parseTranscript")
local readTail = require("@root/adapters/claude/readTail")
local types = require("@root/types")

type Turn = adapterTypes.Turn
type Source = types.Source
type CommandRunner = types.CommandRunner

local TAIL_BYTES = 512 * 1024

-- A session's last turns, prose only. Nil when no transcript has that id.
local function readTurnsAsync(source: Source, _run: CommandRunner, sessionId: string, limit: number): { Turn }?
	local filePath = findTranscript(getClaudeDir(source), sessionId)

	if not filePath then
		return nil
	end

	local turns = parseTranscript(readTail(filePath, TAIL_BYTES)).turns
	local first = math.max(1, #turns - limit + 1)

	return table.move(turns, first, #turns, 1, {})
end

return readTurnsAsync
