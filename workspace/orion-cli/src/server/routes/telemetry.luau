local json = require("@std/json")
local net = require("@lute/net/server")
local process = require("@std/process")

local getStatus = require("@root/telemetry/getStatus")
local serializeStatus = require("@root/telemetry/serializeStatus")
local shared = require("@root/server/routes/shared")
local writeConsent = require("@root/telemetry/writeConsent")

type Response = shared.Response

local telemetry = {}

-- `GET` returns the status, which the app reads on launch to decide whether to
-- ask. `POST {"enabled": true|false}` records the person's answer from the
-- app's dialog or Settings. The environment is the server's, which the app
-- launched.
function telemetry.handle(request: net.ReceivedRequest, root: string, environment: { [string]: string }?): Response
	local resolvedEnvironment = environment or process.env

	if request.method == "GET" then
		return shared.reply(200, serializeStatus(getStatus(root, resolvedEnvironment)))
	end

	if request.method ~= "POST" then
		return shared.reply(405, json.object({ error = "method not allowed" }))
	end

	local didSucceed, response = pcall(function(): Response
		local enabled = shared.parseBody(request).enabled
		assert(type(enabled) == "boolean", "enabled must be true or false")

		writeConsent(root, enabled)

		return shared.reply(200, serializeStatus(getStatus(root, resolvedEnvironment)))
	end)

	return if didSucceed then response :: Response else shared.reply(400, json.object({ error = tostring(response) }))
end

return table.freeze(telemetry)
