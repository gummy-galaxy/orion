local queueEvents = require("@root/telemetry/queueEvents")
local readConsent = require("@root/telemetry/readConsent")
local telemetryTypes = require("@root/telemetry/types")
local writeConsent = require("@root/telemetry/writeConsent")

type Build = telemetryTypes.Build
type Consent = telemetryTypes.Consent

-- Records the person's answer from the app or the CLI. Opting in queues one
-- `telemetry_opted_in` event saying where the choice was made, and choosing
-- "on" again doesn't queue another. Opting out sends nothing.
local function chooseTelemetry(
	root: string,
	enabled: boolean,
	surface: "app" | "cli",
	environment: { [string]: string },
	build: Build?
): Consent
	local previous = readConsent(root)
	local consent = writeConsent(root, enabled)

	if enabled and previous.choice ~= "on" then
		queueEvents(root, {
			{
				name = "telemetry_opted_in",
				timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ") :: string,
				properties = { surface = surface },
			},
		}, environment, build)
	end

	return consent
end

return chooseTelemetry
