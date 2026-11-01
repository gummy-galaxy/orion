local clearTelemetryQueue = require("@root/telemetry/clearTelemetryQueue")
local formatTimestamp = require("@root/common/time/formatTimestamp")
local queueTelemetryEvents = require("@root/telemetry/queueTelemetryEvents")
local readTelemetryConsent = require("@root/telemetry/readTelemetryConsent")
local telemetryTypes = require("@root/telemetry/types")
local types = require("@root/types")
local writeTelemetryConsent = require("@root/telemetry/writeTelemetryConsent")

type Build = types.Build
type Consent = telemetryTypes.Consent

-- Records the person's answer from the app or the CLI.
--
-- Turning sharing on queues a `telemetry_opted_in` event saying where the
-- choice was made. Choosing "on" while it's already on queues nothing more.
-- Like any event, it isn't queued in a dev build or under an override such as
-- `DO_NOT_TRACK`, though the choice is still saved.
--
-- Turning sharing off deletes any events still waiting to be sent.
local function chooseTelemetry(
	root: string,
	enabled: boolean,
	surface: "app" | "cli",
	environment: { [string]: string },
	build: Build?
): Consent
	local previous = readTelemetryConsent(root)
	local consent = writeTelemetryConsent(root, enabled)

	if not enabled then
		clearTelemetryQueue(root)
	elseif previous.choice ~= "on" then
		queueTelemetryEvents(root, {
			{
				name = "telemetry_opted_in",
				timestamp = formatTimestamp(),
				properties = { surface = surface },
			},
		}, environment, build)
	end

	return consent
end

return chooseTelemetry
