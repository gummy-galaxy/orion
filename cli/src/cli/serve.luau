local batteriesCli = require("@batteries/cli")
local process = require("@std/process")
local task = require("@std/task")

local context = require("@root/cli/context")
local parent = require("@root/server/parent")
local server = require("@root/server")

type Context = context.Context

return table.freeze({
	help = "Serve the Orion API and optionally a built app",
	define = function(parser: batteriesCli.Parser)
		parser:add("port", "option", { help = "HTTP port (default 5198)" })
		parser:add("host", "option", { help = "HTTP host (default 127.0.0.1)" })
		parser:add("static", "option", { help = "Built app directory" })
		parser:add("parent-pid", "option", { help = "Exit when this parent process is gone" })
	end,
	run = function(parser: batteriesCli.Parser, options: Context)
		local port = tonumber(parser:get("port") or "5198")
		assert(port and port >= 0 and port <= 65535 and port % 1 == 0, "port must be an integer from 0 to 65535")
		local parentPidText = parser:get("parent-pid")
		local parentPid = if parentPidText then tonumber(parentPidText) else nil
		assert(
			parentPidText == nil or (parentPid and parentPid > 0 and parentPid % 1 == 0),
			"parent-pid must be a positive integer"
		)
		local host = parser:get("host") or "127.0.0.1"
		local running = server.start(options.root, options.workspace, host, port, parser:get("static"))
		options.write(`Orion serving on http://{running.hostname}:{running.port}`)
		while true do
			task.wait(if parentPid then 2 else 3600)
			if parentPid and not parent.isProcessAlive(parentPid) then
				running.close()
				process.exit(0)
			end
		end
	end,
})
