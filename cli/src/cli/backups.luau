local cli = require("@batteries/cli")
local json = require("@std/json")

local context = require("@root/cli/context")
local getBackups = require("@root/store/getBackups")

type Context = context.Context

-- Backup file names carry a compact UTC time such as 20261017T164600Z; output spells it in RFC 3339.
local function formatTime(compact: string): string
	local year, month, day, hour, minute, second = compact:match("^(%d%d%d%d)(%d%d)(%d%d)T(%d%d)(%d%d)(%d%d)Z$")
	return `{year}-{month}-{day}T{hour}:{minute}:{second}Z`
end

return table.freeze({
	help = "List saved Orion data revisions",
	define = function(parser: cli.Parser)
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(_parser: cli.Parser, options: Context)
		local backups = getBackups(options.dir)

		if options.asJson then
			local values: json.Array = {}

			for _, backup in backups do
				table.insert(
					values,
					json.object({ revision = backup.revision, time = formatTime(backup.time), size = backup.size })
				)
			end

			options.write(json.serialize(values, true))
		else
			local lines: { string } = {}

			for _, backup in backups do
				table.insert(lines, `r{backup.revision}  {formatTime(backup.time)}  {backup.size} bytes`)
			end

			options.write(if #lines > 0 then table.concat(lines, "\n") else "No backups.")
		end
	end,
})
