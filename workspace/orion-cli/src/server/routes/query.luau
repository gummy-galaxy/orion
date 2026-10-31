local json = require("@std/json")
local net = require("@lute/net/server")

local runQuery = require("@root/server/runQuery")
local shared = require("@root/server/routes/shared")

type Response = shared.Response

local query = {}

-- POST /api/query runs a query on the canvas `x-orion-canvas` names, or the
-- active one. The event socket answers the same request and keeps it current.
function query.handle(request: net.ReceivedRequest, root: string, active: string): Response
	if request.method ~= "POST" then
		return shared.reply(405, json.object({ error = "method not allowed" }))
	end

	local canvas = request.headers["x-orion-canvas"] or active

	if not shared.isKnownWorkspace(root, canvas) then
		return shared.reply(404, json.object({ error = `unknown canvas: {canvas}` }))
	end

	local didSucceed, response = pcall(function(): json.Object
		return runQuery(root, canvas, shared.parseBody(request))
	end)

	return if didSucceed
		then shared.reply(200, response :: json.Object)
		else shared.reply(400, json.object({ error = tostring(response) }))
end

return table.freeze(query)
