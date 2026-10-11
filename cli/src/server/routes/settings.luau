local json = require("@std/json")
local net = require("@lute/net/server")

local mergeSettings = require("@root/settings/mergeSettings")
local readSettings = require("@root/settings/readSettings")
local shared = require("@root/server/routes/shared")

type Response = shared.Response

-- Preferences are small; this keeps a runaway client from filling the disk.
local MAX_BODY_BYTES = 64 * 1024

local settings = {}

function settings.handle(request: net.ReceivedRequest, root: string): Response
	if request.method == "GET" then
		return shared.reply(200, readSettings(root))
	end

	if request.method ~= "POST" then
		return shared.reply(405, json.object({ error = "method not allowed" }))
	end

	local didSucceed, response = pcall(function(): Response
		assert(#request.body <= MAX_BODY_BYTES, "settings are too large")

		return shared.reply(200, mergeSettings(root, shared.parseBody(request)))
	end)

	return if didSucceed then response :: Response else shared.reply(400, json.object({ error = tostring(response) }))
end

return table.freeze(settings)
