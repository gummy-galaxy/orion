local types = require("@root/types")

type Invoke = (
	{ string },
	{
		dataDir: string,
		workspace: string?,
		write: (string) -> (),
		runner: types.CommandRunner,
		now: () -> string,
	}
) -> ()

local invoke: Invoke? = nil

local function bind(fn: Invoke)
	invoke = fn
end

local function run(
	argv: { string },
	options: {
		dataDir: string,
		workspace: string?,
		write: (string) -> (),
		runner: types.CommandRunner,
		now: () -> string,
	}
)
	assert(invoke, "the MCP command is not ready")
	invoke(argv, options)
end

return table.freeze({
	bind = bind,
	run = run,
})
