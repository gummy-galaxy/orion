local json = require("@std/json")
local net = require("@lute/net/server")

local getErrorText = require("@root/getErrorText")
local shared = require("@root/server/routes/shared")
local store = require("@root/store")

type Response = shared.Response

local log = {}

-- The canvas log, oldest first, for the app to show per card. Entries are only appended, so the app never edits them.
function log.handle(request: net.ReceivedRequest, root: string): Response
	if request.method ~= "GET" then
		return shared.reply(405, json.object({ error = "method not allowed" }))
	end

	local workspace = request.query.canvas
	if not workspace or not shared.isKnownWorkspace(root, workspace) then
		return shared.reply(404, json.object({ error = `unknown canvas: {workspace or ""}` }))
	end

	local didSucceed, result = pcall(store.readLog, store.getWorkspaceDir(root, workspace))
	if not didSucceed then
		return shared.reply(500, json.object({ error = getErrorText(result) }))
	end

	local entries: json.Array = {}
	for _, entry in result do
		table.insert(entries, store.encodeLogEntry(entry))
	end

	return shared.reply(200, json.object({ entries = entries }))
end

return table.freeze(log)
