local cli = require("@batteries/cli")
local json = require("@std/json")

local context = require("@root/cli/context")
local getJson = require("@root/sources")
local loadDoc = require("@root/store/loadDoc")

type Context = context.Context

return table.freeze({
	help = "List configured sources",
	define = function(parser: cli.Parser)
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local values = getJson(loadDoc(options.dir).settings.sources)

		if parser:has("json") then
			options.write(json.serialize(values, true))
			return
		end

		local lines: { string } = {}

		for _, value in values do
			local source = json.asObject(value)

			if source then
				table.insert(lines, `{source.id}  {source.kind}`)
			end
		end

		options.write(if #lines > 0 then table.concat(lines, "\n") else "No sources configured.")
	end,
})
