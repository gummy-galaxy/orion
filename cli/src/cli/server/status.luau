local cli = require("@batteries/cli")
local json = require("@std/json")
local process = require("@std/process")

local context = require("@root/cli/context")
local getRunningRuntime = require("@root/server/getRunningRuntime")
local isProcessAlive = require("@root/server/isProcessAlive")

type Context = context.Context

return table.freeze({
	help = "Report the running Orion server",
	mcp = { annotations = { readOnlyHint = true } },
	define = function(parser: cli.Parser)
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local runtime = getRunningRuntime(options.root, function(pid)
			return isProcessAlive(pid, options.runner)
		end)
		if not runtime then
			options.write(if parser:has("json") then [[{"running":false}]] else "No Orion server is running.")
			process.exit(1)
			return
		end

		if parser:has("json") then
			options.write(json.serialize(
				json.object({
					running = true,
					pid = runtime.pid,
					url = runtime.url,
					canvas = runtime.canvas,
					dataFolder = runtime.dataFolder,
					startedAt = runtime.startedAt,
				}),
				true
			))
		else
			options.write(
				`Orion serving on {runtime.url} (pid {runtime.pid}, canvas {runtime.canvas}, data folder {runtime.dataFolder}, started {runtime.startedAt})`
			)
		end
	end,
})
