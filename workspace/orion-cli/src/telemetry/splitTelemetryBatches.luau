local json = require("@std/json")

local serializeTelemetryEvent = require("@root/telemetry/serializeTelemetryEvent")
local telemetryConstants = require("@root/telemetry/constants")
local telemetryTypes = require("@root/telemetry/types")

type Limits = telemetryTypes.Limits
type QueuedEvent = telemetryTypes.QueuedEvent

-- Splits events into batches within the backend's limits, in order.
local function splitTelemetryBatches(events: { QueuedEvent }, limits: Limits): { { QueuedEvent } }
	local maxEventBytes = math.max(limits.maxBytes - telemetryConstants.ENVELOPE_BYTES, 1)
	local batches: { { QueuedEvent } } = {}
	local current: { QueuedEvent } = {}
	local bytes = 0

	for _, event in events do
		local size = #json.serialize(serializeTelemetryEvent(event)) + 1

		if #current > 0 and (#current >= limits.maxEvents or bytes + size > maxEventBytes) then
			table.insert(batches, current)
			current = {}
			bytes = 0
		end

		table.insert(current, event)
		bytes += size
	end

	if #current > 0 then
		table.insert(batches, current)
	end

	return batches
end

return splitTelemetryBatches
