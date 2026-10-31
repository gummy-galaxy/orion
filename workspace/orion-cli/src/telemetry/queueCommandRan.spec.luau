local test = require("@std/test")

local getBuild = require("@root/telemetry/getBuild")
local queueCommandRan = require("@root/telemetry/queueCommandRan")
local takeQueue = require("@root/telemetry/takeQueue")
local testing = require("@root/testing")
local writeConsent = require("@root/telemetry/writeConsent")

local NOW = "2026-10-30T12:00:00Z"
local RELEASE = getBuild("e87813e")
local RUN: queueCommandRan.Run = { command = "card set", flags = "--json,--status", durationMs = 42, exitCode = 0 }

test.case("a finished command is queued with its name, flags, time, and terminal", function(assert)
	local root = testing.directory("command-ran")
	writeConsent(root, true)

	queueCommandRan(root, RUN, {
		environment = {},
		build = RELEASE,
		isInteractive = function()
			return true
		end,
	})

	local events = takeQueue(root, NOW)
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
	writeConsent(root, true)

	queueCommandRan(root, RUN, {
		environment = {},
		build = RELEASE,
		isInteractive = function(): boolean?
			return nil
		end,
	})

	assert.eq(takeQueue(root, NOW)[1].properties.interactive, nil)
end)

test.case("a machine that isn't sharing never asks the terminal", function(assert)
	local root = testing.directory("command-ran-off")
	local asked = false

	queueCommandRan(root, RUN, {
		environment = {},
		build = RELEASE,
		isInteractive = function()
			asked = true
			return true
		end,
	})

	assert.eq(asked, false)
	assert.eq(#takeQueue(root, NOW), 0)
end)
