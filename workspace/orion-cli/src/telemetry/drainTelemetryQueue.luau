local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")

local fileNames = require("@root/fileNames")
local parseTelemetryEvent = require("@root/telemetry/parseTelemetryEvent")
local telemetryTypes = require("@root/telemetry/types")

type QueuedEvent = telemetryTypes.QueuedEvent

local function readLines(file: path.Pathlike, events: { QueuedEvent }, now: string)
	local didRead, text = pcall(fs.readFileToString, file)
	pcall(fs.remove, file)

	if not didRead then
		return
	end

	for _, line in (text :: string):split("\n") do
		if line ~= "" then
			local didParse, event = pcall(function()
				return parseTelemetryEvent(json.deserialize(line) :: json.Value, now)
			end)

			if didParse then
				table.insert(events, event)
			end
		end
	end
end

--[[
	Empties the queue and returns the events that were in it. The queue file is
	moved aside before it's read. That way, a command that adds an event in the
	meantime starts a new queue file instead of writing to the one being read.
	A line that doesn't parse, such as one cut short, is skipped.
]]
local function drainTelemetryQueue(root: string, now: string): { QueuedEvent }
	local queue = path.join(root, fileNames.telemetryQueue)
	local sending = path.join(root, fileNames.telemetrySending)
	local events: { QueuedEvent } = {}

	-- Left behind by a server that stopped mid-send.
	if fs.exists(sending) then
		readLines(sending, events, now)
	end

	if fs.exists(queue) and pcall(fs.move, queue, sending) then
		readLines(sending, events, now)
	end

	return events
end

return drainTelemetryQueue
