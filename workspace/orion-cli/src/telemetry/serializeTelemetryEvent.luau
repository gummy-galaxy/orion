local json = require("@std/json")

local telemetryTypes = require("@root/telemetry/types")

type QueuedEvent = telemetryTypes.QueuedEvent

-- One event as the queue stores it and the backend takes it.
local function serializeTelemetryEvent(event: QueuedEvent): json.Object
	local properties: json.Object = {}

	for key, value in event.properties do
		properties[key] = value
	end

	return json.object({
		name = event.name,
		sessionId = event.sessionId,
		timestamp = event.timestamp,
		properties = json.object(properties),
	})
end

return serializeTelemetryEvent
