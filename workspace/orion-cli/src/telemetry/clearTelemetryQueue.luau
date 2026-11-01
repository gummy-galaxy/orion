local fs = require("@std/fs")
local path = require("@std/path")

local fileNames = require("@root/fileNames")

--[[
	Deletes every event waiting to be sent, including a batch the server had
	moved aside to send. Opting out calls this, so events queued before then
	can never go out, even if the person opts back in.
]]
local function clearTelemetryQueue(root: string)
	pcall(fs.remove, path.join(root, fileNames.telemetryQueue))
	pcall(fs.remove, path.join(root, fileNames.telemetrySending))
end

return clearTelemetryQueue
