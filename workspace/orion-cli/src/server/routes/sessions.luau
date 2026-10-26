local json = require("@std/json")
local net = require("@lute/net/server")

local getAdapter = require("@root/adapters/getAdapter")
local getErrorText = require("@root/getErrorText")
local getWorkspaceDir = require("@root/store/getWorkspaceDir")
local loadDoc = require("@root/store/loadDoc")
local runCommand = require("@root/command")
local shared = require("@root/server/routes/shared")
local types = require("@root/types")

type Response = shared.Response
type CommandRunner = types.CommandRunner

local DEFAULT_LIMIT = 12
local MAX_LIMIT = 50

local sessions = {}

--[[
	A session's last turns, read live from its agent through the adapter's
	`readTurnsAsync` on each request, since a session ref stores none of what
	was said. `source` is the session ref's source id and `id` its ref id, as
	`<kind>:<session id>`.
]]
function sessions.handleAsync(
	request: net.ReceivedRequest,
	root: string,
	active: string,
	runner: CommandRunner?
): Response
	if request.method ~= "GET" then
		return shared.reply(405, json.object({ error = "method not allowed" }))
	end

	local canvas = request.query.canvas or active
	local sourceId = request.query.source or ""
	local refId = request.query.id or ""
	local limit = math.clamp(math.floor(tonumber(request.query.limit) or DEFAULT_LIMIT), 1, MAX_LIMIT)

	if not shared.isKnownWorkspace(root, canvas) then
		return shared.reply(404, json.object({ error = `unknown canvas: {canvas}` }))
	end

	local succeeded, result, failure = pcall(function(): ({ json.Value }?, string?)
		local doc = loadDoc(getWorkspaceDir(root, canvas))

		for _, source in doc.settings.sources do
			if source.id ~= sourceId then
				continue
			end

			local adapter = getAdapter(source.kind)
			local sessionId = refId:match(`^{source.kind}:(.+)$`)

			if not adapter.agent or not sessionId then
				return nil, `{sourceId} has no session {refId}`
			end

			local turns = adapter.agent.readTurnsAsync(source, runner or runCommand, sessionId, limit)

			if not turns then
				return nil, `no session {refId}`
			end

			local values: { json.Value } = {}

			for _, turn in turns do
				table.insert(values, json.object({ role = turn.role, text = turn.text, at = turn.at }))
			end

			return values, nil
		end

		return nil, `no source with id "{sourceId}"`
	end)

	if not succeeded then
		return shared.reply(500, json.object({ error = getErrorText(result) }))
	elseif not result then
		return shared.reply(404, json.object({ error = failure }))
	end

	return shared.reply(200, json.object({ turns = result :: json.Array }))
end

return table.freeze(sessions)
