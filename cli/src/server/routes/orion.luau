local json = require("@std/json")
local net = require("@lute/net/server")

local graph = require("@root/graph")
local serializeDerived = require("@root/server/serializeDerived")
local shared = require("@root/server/routes/shared")
local store = require("@root/store")

type Response = shared.Response

local orion = {}

function orion.handle(request: net.ReceivedRequest, root: string, active: string): Response
	local didSucceed, response = pcall(function(): Response
		if request.method == "GET" then
			local requested = request.headers["x-orion-workspace"] or active
			if not shared.isKnownWorkspace(root, requested) then
				return shared.reply(404, json.object({ error = `unknown workspace: {requested}` }))
			end
			local requestedDir = store.getWorkspaceDir(root, requested)
			local doc = store.read(requestedDir)
			if not doc then
				return shared.reply(404, json.object({ path = store.filePath(requestedDir), workspace = requested }))
			end
			local response = store.toObject(doc)
			response.derived = serializeDerived(graph.derive(doc))
			return shared.reply(200, response)
		end
		return shared.reply(405, json.object({ error = "method not allowed" }))
	end)
	return if didSucceed then response :: Response else shared.reply(500, json.object({ error = tostring(response) }))
end

return table.freeze(orion)
