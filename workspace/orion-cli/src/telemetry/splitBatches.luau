local json = require("@std/json")

local serializeQueuedEvent = require("@root/telemetry/serializeQueuedEvent")
local telemetryTypes = require("@root/telemetry/types")

type QueuedEvent = telemetryTypes.QueuedEvent

-- The backend takes at most 100 events and 64 KiB a batch. The byte limit
-- leaves room for the install id and build around the events.
local MAX_EVENTS = 100
local MAX_EVENT_BYTES = 60 * 1024

-- Splits events into batches the backend accepts, in order.
local function splitBatches(events: { QueuedEvent }): { { QueuedEvent } }
	local batches: { { QueuedEvent } } = {}
	local current: { QueuedEvent } = {}
	local bytes = 0

	for _, event in events do
		local size = #json.serialize(serializeQueuedEvent(event)) + 1

		if #current > 0 and (#current >= MAX_EVENTS or bytes + size > MAX_EVENT_BYTES) then
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
