local cli = require("@batteries/cli")
local io = require("@lute/io")

local context = require("@root/cli/context")
local getBinaryFingerprint = require("@root/cli/mcp/server/getBinaryFingerprint")
local serve = require("@root/cli/mcp/server/serve")

type Context = context.Context

return table.freeze({
	help = "Serve Orion's agent tools over MCP on stdin and stdout",
	define = function(_parser: cli.Parser) end,

	run = function(_parser: cli.Parser, options: Context)
		-- A server keeps the tools of the build it started from, so it stops once that build is replaced.
		local started = getBinaryFingerprint()

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
		end, function()
			return started ~= nil and getBinaryFingerprint() ~= started
		end)
	end,
})
