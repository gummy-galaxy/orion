local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")

local fileNames = require("@root/fileNames")
local telemetryTypes = require("@root/telemetry/types")

type Consent = telemetryTypes.Consent

-- The choice saved for this machine. A missing or unreadable file reads as
-- undecided, so the app asks again rather than guessing.
local function readTelemetryConsent(root: string): Consent
	local file = path.join(root, fileNames.telemetry)

	if not fs.exists(file) then
		return { choice = "undecided" }
	end

	local didRead, object = pcall(function()
		return json.asObject(json.deserialize(fs.readFileToString(file)) :: json.Value)
	end)

	if not didRead or not object then
		return { choice = "undecided" }
	end

	local choice = object.choice
	local installId = object.installId

	if choice == "off" then
		return { choice = "off" }
	end

	if choice == "on" and type(installId) == "string" and installId ~= "" then
		return { choice = "on", installId = installId }
	end

	return { choice = "undecided" }
end

return readTelemetryConsent
