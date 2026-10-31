local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")

local ensureDirectory = require("@root/platform/ensureDirectory")
local fileNames = require("@root/fileNames")
local serializeQueuedEvent = require("@root/telemetry/serializeQueuedEvent")
local telemetryTypes = require("@root/telemetry/types")

type QueuedEvent = telemetryTypes.QueuedEvent

-- Enough for days of events between sends. A machine whose server never runs
-- stops queueing here rather than filling its disk.
local MAX_QUEUE_BYTES = 256 * 1024

--[[
	Appends events to the queue in the data folder, one JSON line each, for
	`orion server start` to send. Commands and the MCP server run briefly or
	shouldn't wait on the network, so they leave events here instead of sending
	them. Returns how many were queued: none once the queue is full.
]]
local function appendQueue(root: string, events: { QueuedEvent }): number
	if #events == 0 then
		return 0
	end

	local file = tostring(path.join(root, fileNames.telemetryQueue))
	local didMeasure, metadata = pcall(fs.metadata, file)
	local size = if didMeasure then metadata.size else 0
	local lines = {}

	for _, event in events do
		local line = json.serialize(serializeQueuedEvent(event)) .. "\n"

		if size + #line > MAX_QUEUE_BYTES then
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

return appendQueue
