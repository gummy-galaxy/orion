local cli = require("@batteries/cli")
local json = require("@std/json")

local checkThemeFile = require("@root/canvas/appearance/checkThemeFile")
local context = require("@root/cli/context")
local readThemeFiles = require("@root/canvas/appearance/readThemeFiles")

type Context = context.Context

return table.freeze({
	help = "List the theme files in the data folder",
	mcp = { annotations = { readOnlyHint = true } },
	define = function(parser: cli.Parser)
		parser:add("json", "flag", { help = "Print JSON" })
	end,
	run = function(parser: cli.Parser, options: Context)
		local items: json.Array = {}
		local lines: { string } = {}

		for _, theme in readThemeFiles(options.root) do
			local label = (theme.file:gsub("%.json$", ""))
			local reason = theme.error

			if theme.text then
				local check = checkThemeFile(theme.file, theme.text)
				label = check.label
				reason = check.error
			end

			local status = if reason then `broken: {reason}` else "ok"

			table.insert(items, json.object({ file = theme.file, label = label, error = reason }))
			table.insert(lines, `{theme.file}  {label}  {status}`)
		end

		options.write(
			if parser:has("json")
				then json.serialize(items, true)
				else if #lines > 0 then table.concat(lines, "\n") else "No theme files."
		)
	end,
})
