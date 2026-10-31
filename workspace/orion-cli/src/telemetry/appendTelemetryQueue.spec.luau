local fs = require("@std/fs")
local path = require("@std/path")
local test = require("@std/test")

local appendTelemetryQueue = require("@root/telemetry/appendTelemetryQueue")
local drainTelemetryQueue = require("@root/telemetry/drainTelemetryQueue")
local telemetryTypes = require("@root/telemetry/types")
local testing = require("@root/testing")

type PropertyValue = telemetryTypes.PropertyValue
type QueuedEvent = telemetryTypes.QueuedEvent

local NOW = "2026-10-30T12:00:00Z"

local function event(name: string, properties: { [string]: PropertyValue }?): QueuedEvent
	return { name = name, timestamp = NOW, properties = properties or {} }
end

test.case("queued events come back in order and leave the queue empty", function(assert)
	local root = testing.directory("telemetry-queue")

	assert.eq(appendTelemetryQueue(root, { event("app_started", { card_count = 3 }) }), 1)
	assert.eq(appendTelemetryQueue(root, { event("cli_command_ran", { command = "card set" }) }), 1)

	local events = drainTelemetryQueue(root, NOW)

	assert.eq(#events, 2)
	assert.eq(events[1].name, "app_started")
	assert.eq(events[1].properties.card_count, 3)
	assert.eq(events[2].properties.command, "card set")
	assert.eq(#drainTelemetryQueue(root, NOW), 0)
end)

test.case("the queue stops growing once it's full", function(assert)
	local root = testing.directory("telemetry-queue-full")
	local large = event("cli_command_ran", { flags = string.rep("x", 1000) })
	local queued = 0

	for _ = 1, 400 do
		queued += appendTelemetryQueue(root, { large })
	end

	assert.eq(queued < 400, true)
	assert.eq(appendTelemetryQueue(root, { large }), 0)
	assert.eq(#drainTelemetryQueue(root, NOW), queued)
	assert.eq(appendTelemetryQueue(root, { large }), 1)
end)

test.case("a line cut short is skipped and the rest still send", function(assert)
	local root = testing.directory("telemetry-queue-broken")
	appendTelemetryQueue(root, { event("app_started") })

	local file = path.join(root, "telemetry-queue.jsonl")
	fs.writeStringToFile(file, fs.readFileToString(file) .. '{"name":"cli_comm')
	appendTelemetryQueue(root, { event("mcp_tool_called") })

	local events = drainTelemetryQueue(root, NOW)

	assert.eq(#events, 1)
	assert.eq(events[1].name, "app_started")
end)

test.case("a queue left mid-send by a stopped server is sent next time", function(assert)
	local root = testing.directory("telemetry-queue-leftover")
	appendTelemetryQueue(root, { event("app_started") })
	fs.move(path.join(root, "telemetry-queue.jsonl"), path.join(root, "telemetry-queue.sending.jsonl"))
	appendTelemetryQueue(root, { event("cli_command_ran") })

	local events = drainTelemetryQueue(root, NOW)

	assert.eq(#events, 2)
	assert.eq(events[1].name, "app_started")
	assert.eq(events[2].name, "cli_command_ran")
end)
