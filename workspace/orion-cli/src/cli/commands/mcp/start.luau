local cli = require("@batteries/cli")
local io = require("@lute/io")
local process = require("@std/process")

local buildTools = require("@root/cli/mcp/catalog/buildTools")
local context = require("@root/cli/context")
local formatTimestamp = require("@root/common/time/formatTimestamp")
local getBinaryFingerprint = require("@root/cli/mcp/server/getBinaryFingerprint")
local mcpTypes = require("@root/cli/mcp/types")
local queueBehindLock = require("@root/cli/mcp/server/queueBehindLock")
local queueTelemetryEvents = require("@root/telemetry/queueTelemetryEvents")
local serve = require("@root/cli/mcp/server/serve")

type Context = context.Context
type Hooks = mcpTypes.Hooks

-- Client names are product names such as claude-code; anything longer is cut.
local MAX_CLIENT_NAME_LENGTH = 64

return table.freeze({
	help = "Serve Orion's agent tools over MCP on stdin and stdout",
	mcp = { skip = "is the MCP server itself" },
	define = function(_parser: cli.Parser) end,

	run = function(_parser: cli.Parser, options: Context)
		-- A server keeps the tools of the build it started from, so it stops
		-- once that build is replaced.
		local started = getBinaryFingerprint()
		local tools = buildTools(options.describe())

		local function runTool(argv: { string }, write: (string) -> ())
			options.execute(argv, {
				dataDir = options.root,
				-- Without --canvas, each call resolves the selected canvas
				-- again, so orion_canvas_use applies to later calls.
				workspace = options.requestedWorkspace,
				write = write,
				runner = options.runner,
				now = options.now,
				-- A nonzero status reports findings, such as canvas check's
				-- layout problems, which the output already carries. Exiting
				-- would stop this server, so the call returns instead.
				exit = function(_code: number) end,
			})
		end

		local function isStale(): boolean
			return started ~= nil and getBinaryFingerprint() ~= started
		end

		local clientName: string? = nil
		local hooks: Hooks = {
			connected = function(name: string?)
				clientName = if name then name:sub(1, MAX_CLIENT_NAME_LENGTH) else nil
			end,
			toolCalled = function(name: string, durationMs: number, failed: boolean)
				local properties: { [string]: string | number | boolean } =
					{ tool = name, duration_ms = durationMs, failed = failed }

				if clientName then
					properties.client = clientName
				end

				queueTelemetryEvents(options.root, {
					{
						name = "mcp_tool_called",
						timestamp = formatTimestamp(),
						properties = properties,
					},
				}, process.env)
			end,
		}

		serve(io.read, io.write, tools, queueBehindLock(runTool), isStale, hooks)
	end,
})
