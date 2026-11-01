-- Values of ORION_TELEMETRY that turn telemetry off.
local OFF_VALUES = { "0", "false", "off", "no" }

-- The environment variable that turns telemetry off whatever was chosen, or
-- nil when none does. DO_NOT_TRACK follows the shared convention, where any
-- value but empty or 0 opts out.
local function getTelemetryOverride(environment: { [string]: string }): string?
	local doNotTrack = environment.DO_NOT_TRACK

	if doNotTrack and doNotTrack ~= "" and doNotTrack ~= "0" then
		return "DO_NOT_TRACK"
	end

	local orionTelemetry = environment.ORION_TELEMETRY

	if orionTelemetry and table.find(OFF_VALUES, orionTelemetry:lower()) then
		return "ORION_TELEMETRY"
	end

	return nil
end

return getTelemetryOverride
