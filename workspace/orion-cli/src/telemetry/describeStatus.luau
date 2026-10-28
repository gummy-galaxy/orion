local telemetryTypes = require("@root/telemetry/types")

type Status = telemetryTypes.Status

local EVENTS_URL = "https://oriongraph.app/reference/telemetry"

-- The status in a sentence or two, as the telemetry commands print it.
local function describeStatus(status: Status): string
	local lines = {
		if status.choice == "on"
			then `Sharing anonymous usage data as install {status.installId}.`
			elseif status.choice == "off" then "Not sharing usage data."
			else "Not sharing usage data. Nobody on this machine has chosen yet.",
	}

	if status.override and status.choice == "on" then
		table.insert(lines, `{status.override} is set, so nothing is sent until it's unset.`)
	elseif status.override then
		table.insert(lines, `{status.override} is set, so nothing is sent whatever is chosen.`)
	end

	table.insert(lines, `The events Orion sends are listed at {EVENTS_URL}.`)

	return table.concat(lines, "\n")
end

return describeStatus
