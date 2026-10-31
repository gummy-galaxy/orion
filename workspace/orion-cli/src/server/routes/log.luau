local json = require("@std/json")
local net = require("@lute/net/server")

local encodeEntry = require("@root/storage/log/encodeEntry")
local getErrorText = require("@root/common/errors/getErrorText")
local getWorkspaceDir = require("@root/storage/canvases/getWorkspaceDir")
local readLog = require("@root/storage/log/readLog")
local shared = require("@root/server/routes/shared")

type Response = shared.Response

local log = {}

-- The canvas log, oldest first, for the app to show per card. Entries are only
-- appended, so the app never edits them.
function log.handle(request: net.ReceivedRequest, root: string): Response
	if request.method ~= "GET" then
		return shared.reply(405, json.object({ error = "method not allowed" }))
	end

	local canvas = request.query.canvas
	if not canvas or not shared.isKnownWorkspace(root, canvas) then
		return shared.reply(404, json.object({ error = `unknown canvas: {canvas or ""}` }))
	end

	local didSucceed, result = pcall(readLog, getWorkspaceDir(root, canvas))
	if not didSucceed then
		return shared.reply(500, json.object({ error = getErrorText(result) }))
	end

	local entries: json.Array = {}
	for _, entry in result do
		table.insert(entries, encodeEntry(entry))
	end

	return shared.reply(200, json.object({ entries = entries }))
end

return table.freeze(log)
