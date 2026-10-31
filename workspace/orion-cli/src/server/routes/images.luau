local json = require("@std/json")
local net = require("@lute/net/server")

local getWorkspaceDir = require("@root/storage/canvases/getWorkspaceDir")
local importImageBytes = require("@root/storage/media/importImageBytes")
local readImageAsset = require("@root/storage/media/readImageAsset")
local shared = require("@root/server/routes/shared")

type Response = shared.Response

local imageRoutes = {}

function imageRoutes.matches(route: string): boolean
	return route == "/api/images" or route:sub(1, 12) == "/api/images/"
end

function imageRoutes.handle(request: net.ReceivedRequest, root: string): Response
	local route = request.path
	local method = request.method
	local workspace = request.query.canvas
	if not workspace or not shared.isKnownWorkspace(root, workspace) then
		return shared.reply(404, json.object({ error = `unknown canvas: {workspace or ""}` }))
	end

	local dir = getWorkspaceDir(root, workspace)
	if route == "/api/images" then
		if method ~= "POST" then
			return shared.reply(405, json.object({ error = "method not allowed" }))
		end

		local didSucceed, result = pcall(importImageBytes, dir, request.body)
		return if didSucceed
			then shared.reply(201, json.object({ asset = result.asset, mime = result.mime }))
			else shared.reply(400, json.object({ error = tostring(result) }))
	end

	if method ~= "GET" then
		return shared.reply(405, json.object({ error = "method not allowed" }))
	end

	local asset = route:sub(13)
	local didSucceed, bytes, mime = pcall(readImageAsset, dir, asset)
	if not didSucceed then
		return shared.reply(400, json.object({ error = tostring(bytes) }))
	end
	if not bytes or not mime then
		return shared.reply(404, json.object({ error = "image not found" }))
	end

	return { status = 200, body = bytes, headers = { ["content-type"] = mime } }
end

return table.freeze(imageRoutes)
