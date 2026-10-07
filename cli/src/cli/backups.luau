local batteriesCli = require("@batteries/cli")
local json = require("@std/json")

local context = require("@root/cli/context")
local store = require("@root/store")

type Context = context.Context

return table.freeze({
	help = "List saved Orion data revisions",
	define = function(parser: batteriesCli.Parser)
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(_parser: batteriesCli.Parser, options: Context)
		local backups = store.getBackups(options.dir)

		if options.asJson then
			local values: json.Array = {}

			for _, backup in backups do
				table.insert(
					values,
					json.object({ revision = backup.revision, time = backup.time, size = backup.size })
				)
			end

			options.write(json.serialize(values, true))
		else
			local lines: { string } = {}

			for _, backup in backups do
				table.insert(lines, `r{backup.revision}  {backup.time}  {backup.size} bytes`)
			end

			options.write(if #lines > 0 then table.concat(lines, "\n") else "No backups.")
		end
	end,
})
