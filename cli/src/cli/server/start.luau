local cli = require("@batteries/cli")
local process = require("@std/process")
local task = require("@std/task")

local context = require("@root/cli/context")
local getParentPid = require("@root/server/getParentPid")
local isProcessAlive = require("@root/server/isProcessAlive")
local server = require("@root/server")

type Context = context.Context

return table.freeze({
	help = "Serve the Orion API for the app and agents",
	define = function(parser: cli.Parser)
		parser:add("port", "option", { help = "HTTP port (default 5198)" })
		parser:add("host", "option", { help = "HTTP host (default 127.0.0.1)" })
		parser:add("static", "option", { help = "Built app directory" })
		parser:add("dev-port", "option", { help = "Port of the app's dev server, whose requests are also answered" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local port = tonumber(parser:get("port") or "5198")
		assert(port and port >= 0 and port <= 65535 and port % 1 == 0, "port must be an integer from 0 to 65535")
		-- Exit once whatever started the server is gone, so a crashed app or dev server can't leave it running.
		local parentProcessId = getParentPid(options.runner)
		local isWatchingParent = parentProcessId ~= nil and parentProcessId > 1
		local devPortOption = parser:get("dev-port")
		local devPort = if devPortOption then tonumber(devPortOption) else nil
		assert(
			devPortOption == nil or (devPort and devPort > 0 and devPort <= 65535 and devPort % 1 == 0),
			"dev-port must be an integer from 1 to 65535"
		)
		local host = parser:get("host") or "127.0.0.1"
		local running = server.start(options.root, options.workspace, host, port, parser:get("static"), devPort)
		options.write(`Orion serving on http://{running.hostname}:{running.port}`)
		local isClosing = false
		local signalHandles: { process.SignalHandle } = {}
		local function close()
			if isClosing then
				return
			end
			isClosing = true
			for _, handle in signalHandles do
				handle:close()
			end
			running.close()
		end
		table.insert(
			signalHandles,
			process.onSignal("SIGINT", function()
				close()
				process.exit(0)
			end)
		)
		table.insert(
			signalHandles,
			process.onSignal("SIGTERM", function()
				close()
				process.exit(0)
			end)
		)

		while true do
			task.wait(if isWatchingParent then 2 else 3600)

			if isWatchingParent and not isProcessAlive(parentProcessId :: number, options.runner) then
				close()
				process.exit(0)
			end
		end
	end,
})
