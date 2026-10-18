local json = require("@std/json")
local net = require("@lute/net/server")

local getClaudeDir = require("@root/adapters/claude/getClaudeDir")
local getErrorText = require("@root/getErrorText")
local getWorkspaceDir = require("@root/store/getWorkspaceDir")
local loadDoc = require("@root/store/loadDoc")
local readTurns = require("@root/adapters/claude/readTurns")
local shared = require("@root/server/routes/shared")

type Response = shared.Response

local TURN_LIMIT = 12

local sessions = {}

-- A session ref's last few turns, read from its agent's transcript on each request. Orion keeps no copy. Sending a
-- follow-up isn't built: see the spike's pull request for what headless resume needs.
function sessions.handle(request: net.ReceivedRequest, root: string, active: string): Response
	if request.method ~= "GET" then
		return shared.reply(405, json.object({ error = "method not allowed" }))
	end

	local canvas = request.query.canvas or active
	local key = request.query.key or ""
	local sessionId = key:match("^claude:([%w%-]+)$")

	if not shared.isKnownWorkspace(root, canvas) then
		return shared.reply(404, json.object({ error = `unknown canvas: {canvas}` }))
	elseif not sessionId then
		return shared.reply(400, json.object({ error = "key must be claude:<session id>" }))
	end

	local succeeded, result = pcall(function()
		local doc = loadDoc(getWorkspaceDir(root, canvas))

		for _, source in doc.settings.sources do
			if source.kind == "claude" then
				return readTurns(getClaudeDir(source), sessionId, TURN_LIMIT)
			end
		end

		return nil
	end)

	if not succeeded then
		return shared.reply(500, json.object({ error = getErrorText(result) }))
	elseif not result then
		return shared.reply(404, json.object({ error = "no transcript for that session" }))
	end

	local turns: json.Array = {}

	for _, turn in result do
		table.insert(turns, json.object({ role = turn.role, text = turn.text, at = turn.at }))
	end

	return shared.reply(200, json.object({ turns = turns }))
end

return table.freeze(sessions)
