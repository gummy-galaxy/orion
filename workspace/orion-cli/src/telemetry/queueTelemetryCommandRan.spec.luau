local test = require("@std/test")

local drainTelemetryQueue = require("@root/telemetry/drainTelemetryQueue")
local getBuild = require("@root/common/getBuild")
local queueTelemetryCommandRan = require("@root/telemetry/queueTelemetryCommandRan")
local testing = require("@root/testing")
local writeTelemetryConsent = require("@root/telemetry/writeTelemetryConsent")

local NOW = "2026-10-30T12:00:00Z"
local RELEASE = getBuild("e87813e")
local RUN: queueTelemetryCommandRan.Run =
	{ command = "card set", flags = "--json,--status", durationMs = 42, exitCode = 0 }

test.case("a finished command is queued with its name, flags, time, and terminal", function(assert)
	local root = testing.directory("command-ran")
	writeTelemetryConsent(root, true)

	queueTelemetryCommandRan(root, RUN, {
		environment = {},
		build = RELEASE,
		isInteractiveTerminal = function()
			return true
		end,
	})

	local events = drainTelemetryQueue(root, NOW)
	assert.eq(#events, 1)
	local properties = events[1].properties
	assert.eq(events[1].name, "cli_command_ran")
	assert.eq(properties.command, "card set")
	assert.eq(properties.flags, "--json,--status")
	assert.eq(properties.duration_ms, 42)
	assert.eq(properties.exit_code, 0)
	assert.eq(properties.interactive, true)
end)

test.case("without a way to ask the terminal, interactive is left out", function(assert)
	local root = testing.directory("command-ran-unknown-terminal")
	writeTelemetryConsent(root, true)

	queueTelemetryCommandRan(root, RUN, {
		environment = {},
		build = RELEASE,
		isInteractiveTerminal = function(): boolean?
			return nil
		end,
	})

	assert.eq(drainTelemetryQueue(root, NOW)[1].properties.interactive, nil)
end)

test.case("a machine that isn't sharing never asks the terminal", function(assert)
	local root = testing.directory("command-ran-off")
	local asked = false

	queueTelemetryCommandRan(root, RUN, {
		environment = {},
		build = RELEASE,
		isInteractiveTerminal = function()
			asked = true
			return true
		end,
	})

	assert.eq(asked, false)
	assert.eq(#drainTelemetryQueue(root, NOW), 0)
end)
