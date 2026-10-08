local types = require("@root/types")

type Options = {
	dataDir: string,
	workspace: string?,
	write: (string) -> (),
	runner: types.CommandRunner,
	now: () -> string,
}

type Invoke = ({ string }, Options) -> ()

-- The CLI entry point requires the mcp command, so requiring it back would be a cycle Luau's
-- type checker rejects. The entry point binds its execute here instead, and bind and run share it.
local invoke: Invoke? = nil

local function bind(execute: Invoke)
	invoke = execute
end

local function run(argv: { string }, options: Options)
	assert(invoke, "the MCP command is not ready")
	invoke(argv, options)
end

return table.freeze({
	bind = bind,
	run = run,
})
