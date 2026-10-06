local batteriesCli = require("@batteries/cli")
local process = require("@std/process")
local task = require("@std/task")

local context = require("@root/cli/context")
local getParentPid = require("@root/server/getParentPid")
local isProcessAlive = require("@root/server/isProcessAlive")
local server = require("@root/server")

type Context = context.Context

return table.freeze({
	help = "Serve the Orion API and optionally a built app",
	define = function(parser: batteriesCli.Parser)
		parser:add("port", "option", { help = "HTTP port (default 5198)" })
		parser:add("host", "option", { help = "HTTP host (default 127.0.0.1)" })
		parser:add("static", "option", { help = "Built app directory" })
	end,
	run = function(parser: batteriesCli.Parser, options: Context)
		local port = tonumber(parser:get("port") or "5198")
		assert(port and port >= 0 and port <= 65535 and port % 1 == 0, "port must be an integer from 0 to 65535")
		-- Exit once whatever started the server is gone, so a crashed app or dev server can't leave it running.
		local parentPid = getParentPid(options.runner)
		local isWatchingParent = parentPid ~= nil and parentPid > 1
		local host = parser:get("host") or "127.0.0.1"
		local running = server.start(options.root, options.workspace, host, port, parser:get("static"))
		options.write(`Orion serving on http://{running.hostname}:{running.port}`)
		while true do
			task.wait(if isWatchingParent then 2 else 3600)
			if isWatchingParent and not isProcessAlive(parentPid :: number, options.runner) then
				running.close()
				process.exit(0)
			end
		end
	end,
})
