local cli = require("@batteries/cli")

local context = require("@root/cli/context")
local createSource = require("@root/sources/createSource")
local parseCommaList = require("@root/cli/parseCommaList")
local store = require("@root/store")

type Context = context.Context

return table.freeze({
	help = "Add a GitHub, Jira, or hop source",
	define = function(parser: cli.Parser)
		parser:add("kind", "positional", { help = "github, jira, or hop" })
		parser:add("host", "option", { help = "GitHub host" })
		parser:add("owners", "option", { help = "GitHub owners, comma-separated" })
		parser:add("include", "option", { help = "Repositories to include, comma-separated" })
		parser:add("exclude", "option", { help = "Repositories to exclude, comma-separated" })
		parser:add("command", "option", { help = "JSON array naming an external command" })
		parser:add("browse", "option", { help = "Jira browse URL" })
		parser:add("id", "option", { help = "Source id" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local kind = assert(parser:get("kind"), "source add needs a kind")
		local values: { [string]: { string } } = {}

		for _, key in { "host", "command", "browse", "id" } do
			local value = parser:get(key)

			if value ~= nil then
				values[key] = { value }
			end
		end

		for _, key in { "owners", "include", "exclude" } do
			local value = parser:get(key)

			if value ~= nil then
				values[key] = parseCommaList(value)
			end
		end

		local source = createSource(kind, values)
		store.transaction(options.dir, function(doc)
			for _, existing in doc.settings.sources do
				assert(existing.id ~= source.id, `source id "{source.id}" already exists`)
			end

			table.insert(doc.settings.sources, source)
		end)

		options.write(`Added source {source.id}`)
	end,
})
