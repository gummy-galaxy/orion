local json = require("@std/json")
local net = require("@lute/net/server")

local deriveTimed = require("@root/server/deriveTimed")
local encodeDocObject = require("@root/storage/files/encodeDocObject")
local getDocPath = require("@root/storage/canvases/getDocPath")
local getWorkspaceDir = require("@root/storage/canvases/getWorkspaceDir")
local performanceSummaries = require("@root/server/performanceSummaries")
local readDoc = require("@root/storage/canvases/readDoc")
local serializeDerived = require("@root/server/serializeDerived")
local shared = require("@root/server/routes/shared")

type Response = shared.Response

local orion = {}

function orion.handle(
	request: net.ReceivedRequest,
	root: string,
	active: string,
	timings: performanceSummaries.Timings?
): Response
	local didSucceed, response = pcall(function(): Response
		if request.method == "GET" then
			local requested = request.headers["x-orion-canvas"] or active
			if not shared.isKnownWorkspace(root, requested) then
				return shared.reply(404, json.object({ error = `unknown canvas: {requested}` }))
			end
			local requestedDir = getWorkspaceDir(root, requested)
			local doc = readDoc(requestedDir)
			if not doc then
				return shared.reply(404, json.object({ path = getDocPath(requestedDir), canvas = requested }))
			end
			local body = encodeDocObject(doc)
			body.derived = serializeDerived(deriveTimed(doc, timings))
			return shared.reply(200, body)
		end
		return shared.reply(405, json.object({ error = "method not allowed" }))
	end)
	return if didSucceed then response :: Response else shared.reply(500, json.object({ error = tostring(response) }))
end

return table.freeze(orion)
