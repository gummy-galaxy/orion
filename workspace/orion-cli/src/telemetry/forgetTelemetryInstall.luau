local json = require("@std/json")

local ensureDirectory = require("@root/common/platform/ensureDirectory")
local fileNames = require("@root/fileNames")
local replaceFile = require("@root/storage/files/replaceFile")
local telemetryTypes = require("@root/telemetry/types")

type Consent = telemetryTypes.Consent

-- Once the backend has accepted a request to delete what was shared under the
-- install id, Orion has no more use for the id. This saves the choice as off
-- with no id, so opting in again starts a new one.
local function forgetTelemetryInstall(root: string): Consent
	ensureDirectory(root)
	replaceFile(root, fileNames.telemetry, json.serialize(json.object({ choice = "off" }), true))

	return { choice = "off" }
end

return forgetTelemetryInstall
