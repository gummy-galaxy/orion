local batteriesCli = require("@batteries/cli")
local io = require("@std/io")
local json = require("@std/json")
local process = require("@std/process")

local catalog = require("@root/cli/mcp/catalog")
local context = require("@root/cli/context")
local install = require("@root/cli/mcp/install")
local platformDirs = require("@root/platformDirs")
local runtime = require("@root/cli/mcp/runtime")

type Context = context.Context

local function arguments(): json.Object
	local raw = io.input()

	if raw == "" then
		return json.object({})
	end

	local decoded = json.asObject(json.deserialize(raw) :: json.Value)
	assert(decoded, "tool arguments must be a JSON object")
	return decoded
end

local function addClient(parser: batteriesCli.Parser, help: string)
	local command = parser:subcommand(help, { help = `{help} the MCP server with Codex, Claude, or Cursor` })
	command:add("help", "flag", { help = "Show this help", aliases = { "h" } })
	command:add("client", "positional", { help = "codex, claude, cursor, or all" })
end

return table.freeze({
	help = "List agent tools, run one, or register the server with Codex, Claude, and Cursor",
	define = function(parser: batteriesCli.Parser)
		local tools = parser:subcommand("tools", { help = "Print the agent tool catalog as JSON" })
		tools:add("help", "flag", { help = "Show this help", aliases = { "h" } })

		local call = parser:subcommand("call", { help = "Run one tool. Pass its arguments as a JSON object on stdin" })
		call:add("help", "flag", { help = "Show this help", aliases = { "h" } })
		call:add("name", "positional", { help = "Tool name" })

		addClient(parser, "register")
		addClient(parser, "unregister")
	end,

	run = function(parser: batteriesCli.Parser, options: Context)
		local name, subcommand = parser:selected()
		assert(name and subcommand, "choose tools, call, register, or unregister")

		if name == "tools" then
			options.write(json.serialize(catalog.schema(), true))
			return
		end

		if name == "register" or name == "unregister" then
			local platform = platformDirs.current()
			local located = install.locate(
				tostring(process.execPath()),
				tostring(process.cwd()),
				tostring(process.homedir()),
				process.env,
				platform
			)
			local request: install.Request = {
				source = located.source,
				cliBin = located.cliBin,
				installDir = located.installDir,
				home = located.home,
				clients = install.clients(subcommand:get("client")),
				write = options.write,
				runner = options.runner,
				env = process.env,
				platform = platform,
			}

			if name == "register" then
				install.register(request)
			else
				install.unregister(request)
			end

			return
		end

		local toolName = assert(subcommand:get("name"), "missing <name>")
		runtime.run(catalog.argv(toolName, arguments()), {
			dataDir = options.root,
			workspace = options.workspace,
			write = options.write,
			runner = options.runner,
			now = options.now,
		})
	end,
})
