local cli = require("@batteries/cli")
local json = require("@std/json")

local context = require("@root/cli/context")
local createSource = require("@root/sources/createSource")
local parseCommaList = require("@root/cli/parseCommaList")
local runTransaction = require("@root/store/runTransaction")
local writeResult = require("@root/cli/writeResult")

type Context = context.Context

type Option = {
	name: string,
	help: string,
	isList: boolean?,
}

type Kind = {
	help: string,
	options: { Option },
}

-- Each kind has its own options, so help lists only the ones it takes. The adapter's
-- createSource validates them.
local KIND_ORDER = { "github", "jira", "hop" }

local KINDS: { [string]: Kind } = {
	github = {
		help = "Add a GitHub source",
		options = {
			{ name = "host", help = "GitHub host" },
			{ name = "owners", help = "GitHub owners, comma-separated", isList = true },
			{ name = "include", help = "Repositories to include, comma-separated", isList = true },
			{ name = "exclude", help = "Repositories to exclude, comma-separated", isList = true },
		},
	},
	jira = {
		help = "Add a Jira source",
		options = {
			{ name = "command", help = "JSON array naming an external command" },
			{ name = "browse", help = "Jira browse URL" },
		},
	},
	hop = {
		help = "Add a hop source",
		options = {
			{ name = "command", help = "JSON array naming an external command" },
		},
	},
}

-- Every kind takes an id on top of its own options.
local ID_OPTION: Option = { name = "id", help = "Source id" }

local function getOptions(kind: string): { Option }
	local options = table.clone(KINDS[kind].options)
	table.insert(options, ID_OPTION)
	return options
end

local function readValues(kind: string, parser: cli.Parser): { [string]: { string } }
	local values: { [string]: { string } } = {}

	for _, option in getOptions(kind) do
		local value = parser:get(option.name)

		if value ~= nil then
			values[option.name] = if option.isList then parseCommaList(value) else { value }
		end
	end

	return values
end

return table.freeze({
	help = "Add a GitHub, Jira, or hop source",
	mcp = { skip = "configures a source with adapter-specific settings, so setup stays in the CLI" },
	define = function(parser: cli.Parser)
		for _, kind in KIND_ORDER do
			local kindParser = parser:subcommand(kind, { help = KINDS[kind].help })
			kindParser:add("help", "flag", { help = "Show this help", aliases = { "h" } })
			kindParser:add("canvas", "option", { help = "Use this canvas for this command" })

			for _, option in getOptions(kind) do
				kindParser:add(option.name, "option", { help = option.help })
			end
		end
	end,

	run = function(parser: cli.Parser, options: Context)
		local kind, kindParser = parser:selected()
		assert(kind and kindParser, "choose github, jira, or hop")

		if kindParser:has("help") then
			options.write(`{KINDS[kind].help}\n\n{kindParser:usage(`orion source add {kind}`)}\n\n{kindParser:help()}`)
			return
		end

		local source = createSource(kind, readValues(kind, kindParser))
		local doc = runTransaction(options.dir, function(current)
			for _, existing in current.settings.sources do
				assert(existing.id ~= source.id, `source id "{source.id}" already exists`)
			end

			table.insert(current.settings.sources, source)
		end)

		writeResult(options, json.object({ revision = doc.revision, id = source.id }), `Added source {source.id}`)
	end,
})
