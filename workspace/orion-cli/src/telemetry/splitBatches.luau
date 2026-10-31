local json = require("@std/json")

local serializeQueuedEvent = require("@root/telemetry/serializeQueuedEvent")
local telemetryTypes = require("@root/telemetry/types")

type Limits = telemetryTypes.Limits
type QueuedEvent = telemetryTypes.QueuedEvent

-- Room left in each batch for the install id and build around the events.
local ENVELOPE_BYTES = 4 * 1024

-- Splits events into batches within the backend's limits, in order.
local function splitBatches(events: { QueuedEvent }, limits: Limits): { { QueuedEvent } }
	local maxEventBytes = math.max(limits.maxBytes - ENVELOPE_BYTES, 1)
	local batches: { { QueuedEvent } } = {}
	local current: { QueuedEvent } = {}
	local bytes = 0

	for _, event in events do
		local size = #json.serialize(serializeQueuedEvent(event)) + 1

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

return splitBatches
