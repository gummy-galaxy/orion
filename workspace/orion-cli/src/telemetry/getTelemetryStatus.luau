local getTelemetryOverride = require("@root/telemetry/getTelemetryOverride")
local readTelemetryConsent = require("@root/telemetry/readTelemetryConsent")
local telemetryTypes = require("@root/telemetry/types")

type Status = telemetryTypes.Status

-- The saved choice together with any environment override, which is what
-- decides whether events may be sent.
local function getTelemetryStatus(root: string, environment: { [string]: string }): Status
	local consent = readTelemetryConsent(root)
	local override = getTelemetryOverride(environment)

	return {
		choice = consent.choice,
		installId = consent.installId,
		override = override,
		enabled = consent.choice == "on" and override == nil,
	}
end

return getTelemetryStatus
