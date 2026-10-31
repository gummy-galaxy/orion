local json = require("@std/json")

local telemetryTypes = require("@root/telemetry/types")

type Status = telemetryTypes.Status

-- The status as `orion telemetry status --json` prints it and the server's
-- telemetry route returns it.
local function serializeStatus(status: Status): json.Object
	return json.object({
		choice = status.choice,
		installId = status.installId,
		override = status.override,
		enabled = status.enabled,
	})
end

return serializeStatus
