local claudeTypes = require("@root/adapters/claude/types")
local findTranscript = require("@root/adapters/claude/findTranscript")
local parseTranscript = require("@root/adapters/claude/parseTranscript")
local readTail = require("@root/adapters/claude/readTail")

type Turn = claudeTypes.Turn

local TAIL_BYTES = 512 * 1024

-- A session's last turns, prose only, for the companion to show. Nil when no transcript has that id.
local function readTurns(dir: string, sessionId: string, limit: number): { Turn }?
	local filePath = findTranscript(dir, sessionId)

	if not filePath then
		return nil
	end

	local turns = parseTranscript(readTail(filePath, TAIL_BYTES)).turns
	local first = math.max(1, #turns - limit + 1)

	return table.move(turns, first, #turns, 1, {})
end

return readTurns
