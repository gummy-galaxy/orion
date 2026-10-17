local cli = require("@batteries/cli")
local json = require("@std/json")

local addThemeFile = require("@root/themes/addThemeFile")
local context = require("@root/cli/context")

type Context = context.Context

return table.freeze({
	help = "Copy a theme file into the data folder, where the app lists it",
	define = function(parser: cli.Parser)
		parser:add("file", "positional", { help = "Theme file (JSON with light and dark token values)" })
		parser:add("json", "flag", { help = "Print JSON" })
	end,
	run = function(parser: cli.Parser, options: Context)
		local added = addThemeFile(options.root, assert(parser:get("file"), "file is required"))

		if parser:has("json") then
			options.write(json.serialize(
				json.object({
					file = added.file,
					label = added.label,
					replaced = added.replaced,
					warnings = added.warnings,
				}),
				true
			))
			return
		end

		local summary = if added.replaced
			then `Replaced theme file {added.file} with {added.label}`
			else `Added theme {added.label} as {added.file}`
		local lines = { summary }

		for _, warning in added.warnings do
			table.insert(lines, `Warning: {warning}`)
		end

		options.write(table.concat(lines, "\n"))
	end,
})
