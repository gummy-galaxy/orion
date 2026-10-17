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
		local dir = store.getWorkspaceDir(root, active)
		if request.method == "GET" then
			local requested = request.headers["x-orion-canvas"] or active
			if not shared.isKnownWorkspace(root, requested) then
				return shared.reply(404, json.object({ error = `unknown canvas: {requested}` }))
			end
			local requestedDir = store.getWorkspaceDir(root, requested)
			local doc = store.read(requestedDir)
			if not doc then
				return shared.reply(404, json.object({ path = store.filePath(requestedDir), canvas = requested }))
			end
			local response = store.toObject(doc)
			response.derived = serializeDerived(graph.derive(doc))
			return shared.reply(200, response)
		elseif request.method == "PUT" then
			local tagged = request.headers["x-orion-canvas"]
			if tagged and tagged ~= active then
				return shared.reply(409, json.object({ error = "canvas changed" }))
			end
			local change = shared.parseBody(request)
			local base = change.baseRevision
			assert(base == json.null or type(base) == "number", "baseRevision must be a number or null")
			local nodes = assert(json.asArray(change.nodes), "nodes must be an array")
			local links = assert(json.asArray(change.links), "links must be an array")
			local stickersValue: json.Value? = change.stickers
			local loadoutValue: json.Value? = change.stickerLoadout
			local stickers = if stickersValue ~= nil
				then assert(json.asArray(stickersValue), "stickers must be an array")
				else nil
			local stickerLoadout = if loadoutValue ~= nil
				then assert(json.asArray(loadoutValue), "stickerLoadout must be an array")
				else nil
			local isSaved, revision = store.put(
				dir,
				if base == json.null then nil else base :: number,
				nodes,
				links,
				stickers,
				stickerLoadout
			)
			return shared.reply(if isSaved then 200 else 409, json.object({ revision = revision or json.null }))
		end
		return shared.reply(405, json.object({ error = "method not allowed" }))
	end)
	return if didSucceed then response :: Response else shared.reply(500, json.object({ error = tostring(response) }))
end

return table.freeze(orion)
