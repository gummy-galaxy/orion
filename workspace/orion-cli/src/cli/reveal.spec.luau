local path = require("@std/path")
local test = require("@std/test")

local getWorkspaceDir = require("@root/store/getWorkspaceDir")
local runTransaction = require("@root/store/runTransaction")
local testing = require("@root/testing")

local function failure(run, args: { string }, runner): string
	local ok, message = pcall(run, args, runner)
	assert(not ok, `expected {table.concat(args, " ")} to fail`)
	return tostring(message)
end

test.case("reveal needs the items to show", function(assert)
	local _, run = testing.createHarness("reveal-no-ids")
	assert.strContains(failure(run, { "reveal" }), "say what to reveal")
end)

test.case("reveal names the canvas that lacks an item", function(assert)
	local _, run = testing.createHarness("reveal-unknown")
	run({ "canvas", "create", "planning" })
	local runner = function()
		return testing.result(false, "")
	end
	assert.strContains(
		failure(run, { "reveal", "nowhere" }, runner),
		`"nowhere" isn't on canvas default or any other canvas`
	)
	assert.strContains(
		failure(run, { "reveal", "ci", "--canvas", "planning" }, runner),
		`"ci" isn't on canvas planning`
	)
end)

test.case("reveal opens the installed app on this data folder when none is running", function(assert)
	local dir, run = testing.createHarness("reveal-launch")
	local launched: { string } = {}
	local runner = function(args: { string })
		launched = args
		return testing.result(false, "")
	end
	assert.strContains(failure(run, { "reveal", "ci" }, runner), "Could not open Orion")
	assert.eq(launched[1], "open")
	assert.eq(launched[2], "--env")
	assert.eq(launched[3], `ORION_DATA_DIR={dir}`)
	assert.strContains(launched[5], tostring(path.join("Applications", "Orion.app")))
end)

test.case("reveal finds an item on another canvas before it opens the app", function(assert)
	local root, run = testing.createHarness("reveal-other-canvas")
	run({ "canvas", "create", "planning" })
	runTransaction(getWorkspaceDir(root, "planning"), function(doc)
		table.insert(doc.nodes, testing.task("plan", "Plan the release", "todo"))
	end)
	local launches = 0
	local runner = function()
		launches += 1
		return testing.result(false, "")
	end
	assert.strContains(failure(run, { "reveal", "plan" }, runner), "Could not open Orion")
	assert.eq(launches, 1)
end)
