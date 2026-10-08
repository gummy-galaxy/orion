local batteriesCli = require("@batteries/cli")
local luteIo = require("@lute/io")
local path = require("@std/path")
local process = require("@std/process")

local context = require("@root/cli/context")
local getClients = require("@root/cli/mcp/clients/getClients")
local mcpTypes = require("@root/cli/mcp/types")
local platformDirs = require("@root/platformDirs")
local registerClients = require("@root/cli/mcp/clients/registerClients")
local runtime = require("@root/cli/mcp/runtime")
local serve = require("@root/cli/mcp/server/serve")
local unregisterClients = require("@root/cli/mcp/clients/unregisterClients")

type ClientRequest = mcpTypes.ClientRequest
type Context = context.Context

local function addClient(parser: batteriesCli.Parser, help: string)
	local command = parser:subcommand(help, { help = `{help} the MCP server with Codex, Claude, or Cursor` })
	command:add("help", "flag", { help = "Show this help", aliases = { "h" } })
	command:add("client", "positional", { help = "codex, claude, cursor, or all" })
end

return table.freeze({
	help = "Serve Orion's agent tools over MCP, or register the server with Codex, Claude, and Cursor",
	define = function(parser: batteriesCli.Parser)
		local serve = parser:subcommand("serve", { help = "Run the MCP server over stdin and stdout" })
		serve:add("help", "flag", { help = "Show this help", aliases = { "h" } })

		addClient(parser, "register")
		addClient(parser, "unregister")
	end,

	run = function(parser: batteriesCli.Parser, options: Context)
		local name, subcommand = parser:selected()
		assert(name and subcommand, "choose serve, register, or unregister")

		if name == "serve" then
			serve(luteIo.read, luteIo.write, function(argv, write)
				runtime.run(argv, {
					dataDir = options.root,
					-- Resolved on every call so orion_select_workspace applies to later calls.
					workspace = nil,
					write = write,
					runner = options.runner,
					now = options.now,
				})
			end)
			return
		end

		local request: ClientRequest = {
			binary = tostring(path.normalize(process.execPath())),
			home = tostring(process.homedir()),
			clients = getClients(subcommand:get("client")),
			write = options.write,
			runner = options.runner,
			environment = process.env,
			platform = platformDirs.current(),
		}

		if name == "register" then
			registerClients(request)
		else
			unregisterClients(request)
		end
	end,
})
