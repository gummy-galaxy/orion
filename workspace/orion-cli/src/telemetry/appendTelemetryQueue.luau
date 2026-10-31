local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")

local ensureDirectory = require("@root/common/platform/ensureDirectory")
local fileNames = require("@root/fileNames")
local serializeTelemetryEvent = require("@root/telemetry/serializeTelemetryEvent")
local telemetryConstants = require("@root/telemetry/constants")
local telemetryTypes = require("@root/telemetry/types")

type QueuedEvent = telemetryTypes.QueuedEvent

--[[
	Adds events to the queue file in the data folder, one JSON line each, for
	`orion server start` to send later. CLI commands finish quickly, and the
	MCP server that agents talk to shouldn't wait on the network, so both leave
	their events here instead of sending them.

	The queue has a size limit. Events that would push it past the limit are
	dropped, along with any after them. Returns how many events were added.
]]
local function appendTelemetryQueue(root: string, events: { QueuedEvent }): number
	if #events == 0 then
		return 0
	end

	local file = path.join(root, fileNames.telemetryQueue)
	local didMeasure, metadata = pcall(fs.metadata, file)
	local size = if didMeasure then metadata.size else 0
	local lines = {}

	for _, event in events do
		local line = json.serialize(serializeTelemetryEvent(event)) .. "\n"

		if size + #line > telemetryConstants.MAX_QUEUE_BYTES then
			break
		end

		size += #line
		table.insert(lines, line)
	end

	if #lines == 0 then
		return 0
	end

	ensureDirectory(root)

	local handle = fs.open(file, "a")
	local didWrite, message = pcall(fs.write, handle, table.concat(lines))
	fs.close(handle)

	if not didWrite then
		error(message, 0)
	end

	return #lines
end

return appendTelemetryQueue
