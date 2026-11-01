--[[
	Writes the checked-in files generated from the CLI's source. Commit what it
	writes. With `--check`, each generator leaves its files as they were, and
	the script exits nonzero when one is out of date.

	lute run generate [--check]
		Runs every generator below.

	lute run generate docs [--check]
		Writes the CLI, MCP, and telemetry reference pages in docs/reference/.
		Run it after changing a command, an option, an MCP tool, or a telemetry
		event. It formats the pages with the docs site's Prettier, so run
		`npm ci` in docs/ first.

	lute run generate geometry [--check]
		Writes workspace/orion-app/src/geometry.ts from the CLI's geometry
		constants. Run it after changing workspace/orion-cli/src/geometry.luau.

	lute run generate telemetry [--check]
		Writes docs/public/reference/telemetry.json, the telemetry event
		catalog the backend checks events against. Run it after changing
		workspace/orion-cli/src/telemetry/events.luau, and copy the result over
		the backend's catalog.json.
]]
local process = require("@std/process")

local runScript = require("@root/common/process/runScript")

local generateDocs = require("@self/docs")
local generateGeometry = require("@self/geometry")
local generateTelemetry = require("@self/telemetry")

local GENERATORS: { [string]: (checkOnly: boolean) -> boolean } = {
	docs = generateDocs,
	geometry = generateGeometry,
	telemetry = generateTelemetry,
}

runScript(function()
	local checkOnly = table.find(process.args, "--check") ~= nil
	local name = process.args[2]
	local upToDate = true

	if name == nil or name == "--check" then
		upToDate = generateDocs(checkOnly) and upToDate
		upToDate = generateGeometry(checkOnly) and upToDate
		upToDate = generateTelemetry(checkOnly) and upToDate
	else
		local generator = GENERATORS[name]
		assert(generator, `unknown generator {name}; try docs, geometry, or telemetry`)
		upToDate = generator(checkOnly)
	end

	if not upToDate then
		process.exit(1)
	end
end)
