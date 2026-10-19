local cli = require("@batteries/cli")
local io = require("@lute/io")

local buildTools = require("@root/cli/mcp/catalog/buildTools")
local context = require("@root/cli/context")
local getBinaryFingerprint = require("@root/cli/mcp/server/getBinaryFingerprint")
local queueBehindLock = require("@root/cli/mcp/server/queueBehindLock")
local serve = require("@root/cli/mcp/server/serve")

type Context = context.Context

return table.freeze({
	help = "Serve Orion's agent tools over MCP on stdin and stdout",
	mcp = { skip = "is the MCP server itself" },
	define = function(_parser: cli.Parser) end,

	run = function(_parser: cli.Parser, options: Context)
		-- A server keeps the tools of the build it started from, so it stops once that build is replaced.
		local started = getBinaryFingerprint()
		local tools = buildTools(options.describe())

		local function runTool(argv: { string }, write: (string) -> ())
			options.execute(argv, {
				dataDir = options.root,
				-- Without --canvas, each call resolves the selected canvas again, so
				-- orion_canvas_use applies to later calls.
				workspace = options.requestedWorkspace,
				write = write,
				runner = options.runner,
				now = options.now,
				-- A nonzero status reports findings, such as canvas check's layout problems, which the
				-- output already carries. Exiting would stop this server, so the call returns instead.
				exit = function(_code: number) end,
			})
		end

		local function isStale(): boolean
			return started ~= nil and getBinaryFingerprint() ~= started
		end

		serve(io.read, io.write, tools, queueBehindLock(runTool), isStale)
	end,
})
