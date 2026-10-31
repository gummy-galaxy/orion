local DEFAULT_ENDPOINT = "https://api.oriongraph.app/telemetry/v1/events"

-- Where batches go. `ORION_TELEMETRY_ENDPOINT` points them at a test backend
-- instead, so moving hosts never needs a new client.
local function getEndpoint(environment: { [string]: string }): string
	local endpoint = environment.ORION_TELEMETRY_ENDPOINT

	return if endpoint and endpoint ~= "" then endpoint else DEFAULT_ENDPOINT
end

return getEndpoint
