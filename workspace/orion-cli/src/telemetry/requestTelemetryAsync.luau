local net = require("@std/net")
local task = require("@std/task")

local telemetryConstants = require("@root/telemetry/constants")

--[[
	Makes a request to the telemetry backend and returns its response, or why
	there isn't one. Requests in Lute, the runtime Orion's CLI runs on, can't
	set a timeout of their own. So this stops waiting after `timeoutSeconds`,
	and a request still running then finishes in the background, unused.
]]
local function requestTelemetryAsync(
	url: string,
	metadata: net.Metadata,
	timeoutSeconds: number
): (net.Response?, string?)
	local isDone = false
	local response: net.Response?
	local failure: string?

	task.spawn(function()
		local didSend, result = pcall(net.request, url, metadata)

		if didSend then
			response = result
		else
			failure = tostring(result)
		end

		isDone = true
	end)

	local waited = 0

	while not isDone and waited < timeoutSeconds do
		task.wait(telemetryConstants.POLL_SECONDS)
		waited += telemetryConstants.POLL_SECONDS
	end

	if not isDone then
		return nil, `no answer within {timeoutSeconds} seconds`
	end

	return response, failure
end

return requestTelemetryAsync
