local telemetryConstants = require("@root/telemetry/constants")

export type EndpointName = "events" | "config"

--[[
	Builds the address of one of the backend's endpoints from its base address.
	`ORION_TELEMETRY_URL` replaces the base, so a test backend gets every
	endpoint without a new build.
]]
local function getTelemetryEndpoint(environment: { [string]: string }, name: EndpointName): string
	local override = environment.ORION_TELEMETRY_URL
	local base = if override and override ~= "" then override else telemetryConstants.BASE_URL

	return `{base}/{name}`
end

return getTelemetryEndpoint
