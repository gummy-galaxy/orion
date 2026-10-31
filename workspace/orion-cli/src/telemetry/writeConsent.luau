local json = require("@std/json")

local createId = require("@root/graph/createId")
local ensureDirectory = require("@root/platform/ensureDirectory")
local fileNames = require("@root/fileNames")
local readConsent = require("@root/telemetry/readConsent")
local replaceFile = require("@root/store/replaceFile")
local telemetryTypes = require("@root/telemetry/types")

type Consent = telemetryTypes.Consent

-- Saves the choice for this machine. Opting in keeps an existing install id
-- or creates one, and opting out deletes it, so a later opt-in starts a new
-- anonymous install.
local function writeConsent(root: string, enabled: boolean): Consent
	local current = readConsent(root)
	local consent: Consent = if enabled
		then { choice = "on", installId = current.installId or createId() }
		else { choice = "off" }

	ensureDirectory(root)
	replaceFile(
		root,
		fileNames.telemetry,
		json.serialize(json.object({ choice = consent.choice, installId = consent.installId }), true)
	)

	return consent
end

return writeConsent
