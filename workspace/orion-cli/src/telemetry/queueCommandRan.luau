local canQueue = require("@root/telemetry/canQueue")
local isInteractive = require("@root/telemetry/isInteractive")
local queueEvents = require("@root/telemetry/queueEvents")
local telemetryTypes = require("@root/telemetry/types")

type Build = telemetryTypes.Build
type PropertyValue = telemetryTypes.PropertyValue

export type Run = {
	-- The command's name, such as "card set", never its arguments.
	command: string,
	-- From collectFlagNames.
	flags: string,
	durationMs: number,
	exitCode: number,
}

export type Options = {
	environment: { [string]: string },
	build: Build?,
	-- Stands in for asking the terminal in specs.
	isInteractive: (() -> boolean?)?,
}

-- Queues `cli_command_ran` for a command that finished. A machine that isn't
-- sharing returns before asking whether a terminal is attached, which costs a
-- process.
local function queueCommandRan(root: string, run: Run, options: Options)
	if not canQueue(root, options.environment, options.build) then
		return
	end

	local properties: { [string]: PropertyValue } = {
		command = run.command,
		flags = run.flags,
		duration_ms = run.durationMs,
		exit_code = run.exitCode,
	}
	local interactive = (options.isInteractive or isInteractive)()

	if interactive ~= nil then
		properties.interactive = interactive
	end

	queueEvents(root, {
		{
			name = "cli_command_ran",
			timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ") :: string,
			properties = properties,
		},
	}, options.environment, options.build)
end

return queueCommandRan
