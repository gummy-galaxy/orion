local json = require("@std/json")

local createId = require("@root/common/createId")
local ensureDirectory = require("@root/common/platform/ensureDirectory")
local fileNames = require("@root/fileNames")
local readTelemetryConsent = require("@root/telemetry/readTelemetryConsent")
local replaceFile = require("@root/storage/files/replaceFile")
local telemetryTypes = require("@root/telemetry/types")

type Consent = telemetryTypes.Consent

-- Saves the choice for this machine. Opting in keeps an existing install id
-- or creates one. Opting out keeps it too, so data shared before then can
-- still be deleted under it.
local function writeTelemetryConsent(root: string, enabled: boolean): Consent
	local current = readTelemetryConsent(root)
	local consent: Consent = if enabled
		then { choice = "on", installId = current.installId or createId() }
		else { choice = "off", installId = current.installId }

	ensureDirectory(root)
	replaceFile(
		root,
		fileNames.telemetry,
		json.serialize(json.object({ choice = consent.choice, installId = consent.installId }), true)
	)

	return consent
end

return writeTelemetryConsent
