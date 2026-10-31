local cli = require("@batteries/cli")
local json = require("@std/json")

local context = require("@root/cli/context")
local convertToJson = require("@root/canvas/suggestions/convertToJson")
local getStored = require("@root/canvas/suggestions/getStored")
local loadDoc = require("@root/storage/canvases/loadDoc")

type Context = context.Context

return table.freeze({
	help = "List the stored group suggestions",
	mcp = { annotations = { readOnlyHint = true } },
	define = function(parser: cli.Parser)
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(_parser: cli.Parser, options: Context)
		local result = getStored(loadDoc(options.dir))

		if options.asJson then
			options.write(json.serialize(convertToJson(result), true))
		else
			local lines: { string } = {}

			for _, group in result.groups do
				table.insert(
					lines,
					`{group.id}  {group.title}  [{table.concat(group.members, ", ")}] — {group.reason}`
				)
			end

			options.write(if #lines > 0 then table.concat(lines, "\n") else "No group suggestions.")
		end
	end,
})
