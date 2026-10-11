local json = require("@std/json")
local net = require("@lute/net/server")

local applyCanvasStyle = require("@root/style/applyCanvasStyle")
local shared = require("@root/server/routes/shared")
local store = require("@root/store")

type Response = shared.Response

local canvasStyle = {}

-- The app writes the canvas's cover and background here. A null value clears one, and an absent one keeps it.
local function changeFrom(value: json.Value?): string?
	if value == nil then
		return nil
	end

	if value == json.null then
		return ""
	end

	assert(type(value) == "string", "cover and background must be strings or null")
	return value
end

function canvasStyle.handle(request: net.ReceivedRequest, root: string, active: string): Response
	if request.method ~= "PUT" then
		return shared.reply(405, json.object({ error = "method not allowed" }))
	end

	local tagged = request.headers["x-orion-workspace"]
	if tagged and tagged ~= active then
		return shared.reply(409, json.object({ error = "workspace changed" }))
	end

	local didSucceed, failure = pcall(function()
		local change = shared.parseBody(request)
		local dir = store.getWorkspaceDir(root, active)
		store.putCanvasStyle(dir, function(doc)
			applyCanvasStyle(doc, dir, {
				cover = changeFrom(change.cover),
				background = changeFrom(change.background),
			})
		end)
	end)

	if not didSucceed then
		return shared.reply(400, json.object({ error = tostring(failure) }))
	end

	return shared.reply(200, json.object({}))
end

return table.freeze(canvasStyle)
