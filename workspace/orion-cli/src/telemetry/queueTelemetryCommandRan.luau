local canQueueTelemetry = require("@root/telemetry/canQueueTelemetry")
local formatTimestamp = require("@root/time/formatTimestamp")
local isInteractiveTerminal = require("@root/platform/isInteractiveTerminal")
local queueTelemetryEvents = require("@root/telemetry/queueTelemetryEvents")
local telemetryTypes = require("@root/telemetry/types")
local types = require("@root/types")

type Build = types.Build
type PropertyValue = telemetryTypes.PropertyValue

export type Run = {
	-- The command's name, such as "card set", never its arguments.
	command: string,
	-- From collectTelemetryFlagNames.
	flags: string,
	durationMs: number,
	exitCode: number,
}

export type Options = {
	environment: { [string]: string },
	build: Build?,
	-- Stands in for asking the terminal in specs.
	isInteractiveTerminal: (() -> boolean?)?,
}

-- Queues `cli_command_ran` for a command that finished. A machine that isn't
-- sharing returns before asking whether a terminal is attached, which costs a
-- process.
local function queueTelemetryCommandRan(root: string, run: Run, options: Options)
	if not canQueueTelemetry(root, options.environment, options.build) then
		return
	end

	local properties: { [string]: PropertyValue } = {
		command = run.command,
		flags = run.flags,
		duration_ms = run.durationMs,
		exit_code = run.exitCode,
	}
	local interactive = (options.isInteractiveTerminal or isInteractiveTerminal)()

	if interactive ~= nil then
		properties.interactive = interactive
	end

	queueTelemetryEvents(root, {
		{
			name = "cli_command_ran",
			timestamp = formatTimestamp(),
			properties = properties,
		},
	}, options.environment, options.build)
end

return queueTelemetryCommandRan
