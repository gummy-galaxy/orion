local types = require("@root/types")

type CommandRunner = types.CommandRunner

local function runClientCommand(runner: CommandRunner, argv: { string }, required: boolean)
	local result = runner(argv, nil)

	if required then
		assert(result.ok, `{argv[1]} failed ({result.exitCode})`)
	end
end

return runClientCommand
