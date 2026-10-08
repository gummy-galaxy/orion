local batteriesCli = require("@batteries/cli")
local json = require("@std/json")

local context = require("@root/cli/context")
local store = require("@root/store")

type Context = context.Context

return table.freeze({
	help = "Create the selected workspace's Orion data file",
	define = function(parser: batteriesCli.Parser)
		parser:add("owner", "option", { help = "Default GitHub owner" })
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: batteriesCli.Parser, options: Context)
		store.initialize(options.dir, parser:get("owner"))
		local file = store.filePath(options.dir)
		options.write(
			if options.asJson
				then json.serialize(json.object({ path = file, workspace = options.workspace }), true)
				else `Created Orion data at {file}`
		)
	end,
})
