local getOverride = require("@root/telemetry/getOverride")
local readConsent = require("@root/telemetry/readConsent")
local telemetryTypes = require("@root/telemetry/types")

type Status = telemetryTypes.Status

-- The saved choice together with any environment override, which is what
-- decides whether events may be sent.
local function getStatus(root: string, environment: { [string]: string }): Status
	local consent = readConsent(root)
	local override = getOverride(environment)

	return {
		choice = consent.choice,
		installId = consent.installId,
		override = override,
		enabled = consent.choice == "on" and override == nil,
	}
end

return getStatus
