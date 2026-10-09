local cli = require("@batteries/cli")
local io = require("@lute/io")

local context = require("@root/cli/context")
local serve = require("@root/cli/mcp/server/serve")

type Context = context.Context

return table.freeze({
	help = "Serve Orion's agent tools over MCP on stdin and stdout",
	define = function(_parser: cli.Parser) end,

	run = function(_parser: cli.Parser, options: Context)
		serve(io.read, io.write, function(argv, write)
			options.execute(argv, {
				dataDir = options.root,
				-- Without --workspace, each call resolves the selected workspace again, so
				-- orion_select_workspace applies to later calls.
				workspace = options.requestedWorkspace,
				write = write,
				runner = options.runner,
				now = options.now,
			})
		end)
	end,
})
