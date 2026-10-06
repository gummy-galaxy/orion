local batteriesCli = require("@batteries/cli")

local context = require("@root/cli/context")
local sources = require("@root/sources")
local store = require("@root/store")

type Context = context.Context

-- Batteries' option parser retains only the last value. Read the add command's
-- arguments here so repeated --owner, --include, and --exclude survive.
local function getOptions(args: { string }): { [string]: { string } }
	local index = 1
	if args[index] == "--workspace" then
		index += 2
	end
	assert(args[index] == "source", "expected source command")
	index += 1
	if args[index] == "--workspace" then
		index += 2
	end
	assert(args[index] == "add", "expected source add command")
	index += 1
	local values: { [string]: { string } } = {}
	local hasKind = false
	while index <= #args do
		local key = args[index]:match("^%-%-([%w%-]+)$")
		if not key then
			assert(not hasKind, `unexpected argument {args[index]}`)
			hasKind = true
			index += 1
			continue
		end
		local value = assert(args[index + 1], `missing value for --{key}`)
		if key ~= "workspace" then
			values[key] = values[key] or {}
			table.insert(values[key], value)
		end
		index += 2
	end
	return values
end

return table.freeze({
	help = "Add a GitHub, Jira, or hop source",
	define = function(parser: batteriesCli.Parser)
		parser:add("kind", "positional", { help = "github, jira, or hop" })
		parser:add("host", "option", { help = "GitHub host" })
		parser:add("owner", "option", { help = "GitHub owner; repeat for more" })
		parser:add("include", "option", { help = "Only include this repository; repeat for more" })
		parser:add("exclude", "option", { help = "Exclude this repository; repeat for more" })
		parser:add("command", "option", { help = "JSON array naming an external command" })
		parser:add("browse", "option", { help = "Jira browse URL" })
		parser:add("id", "option", { help = "Source id" })
	end,
	run = function(parser: batteriesCli.Parser, options: Context)
		local kind = assert(parser:get("kind"), "source add needs a kind")
		local source = sources.createSource(kind, getOptions(options.args))
		store.transaction(options.dir, function(doc)
			for _, existing in doc.settings.sources do
				assert(existing.id ~= source.id, `source id "{source.id}" already exists`)
			end
			table.insert(doc.settings.sources, source)
		end)
		options.write(`Added source {source.id}`)
	end,
})
