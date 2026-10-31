local cli = require("@batteries/cli")
local json = require("@std/json")

local addArgument = require("@root/cli/arguments/addArgument")
local cliTypes = require("@root/cli/types")
local context = require("@root/cli/context")
local createSource = require("@root/sources/createSource")
local definitions = require("@root/cli/definitions")
local parseCommaList = require("@root/cli/arguments/parseCommaList")
local runTransaction = require("@root/storage/transactions/runTransaction")
local setSourceCommand = require("@root/sources/setSourceCommand")
local types = require("@root/types")
local writeResult = require("@root/cli/output/writeResult")

type Context = context.Context
type Source = types.Source

type Option = {
	name: string,
	help: string,
	isList: boolean?,
	-- A command is a program for Orion to run, which only a person at the CLI
	-- chooses.
	isCommand: boolean?,
	-- The kind's createSource fails without it, so a tool call must give it.
	isRequired: boolean?,
}

type Kind = {
	help: string,
	options: { Option },
	mcp: cliTypes.ToolDeclaration,
}

local COMMAND_REASON = "runs a program, which only a person at the CLI should choose"

-- Each kind has its own options, so help lists only the ones it takes. The
-- adapter's createSource validates them.
local KIND_ORDER = { "github", "jira", "hop", "claude" }

local KINDS: { [string]: Kind } = {
	github = {
		help = "Add a GitHub source",
		options = {
			{ name = "host", help = "GitHub host", isRequired = true },
			{ name = "owners", help = "GitHub owners, comma-separated", isList = true, isRequired = true },
			{ name = "include", help = "Repositories to include, comma-separated", isList = true },
			{ name = "exclude", help = "Repositories to exclude, comma-separated", isList = true },
		},
		mcp = {},
	},
	jira = {
		help = "Add a Jira source",
		options = {
			{ name = "command", help = "JSON array naming an external command", isCommand = true },
			{ name = "browse", help = "Jira browse URL" },
		},
		mcp = { skip = "takes the command Jira runs, which only a person at the CLI should choose" },
	},
	hop = {
		help = "Add a hop source",
		options = {
			{ name = "command", help = "JSON array naming the hop executable", isCommand = true },
		},
		mcp = { omit = { { option = "command", reason = COMMAND_REASON } } },
	},
	claude = {
		help = "Add a Claude Code source, which puts sessions on the cards whose branch they ran on",
		options = {
			{ name = "dir", help = "Claude Code's data folder, ~/.claude by default" },
		},
		mcp = {
			skip = "reads every Claude Code transcript on this machine, which only a person at the CLI should allow",
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

-- A source added again keeps the settings it's given and the ones it had, so
-- setting this machine's command for a source that came with a shared canvas
-- doesn't need its other settings repeated.
local function mergeSource(existing: Source, source: Source)
	for key, value in source :: any do
		(existing :: any)[key] = value
	end
end

return table.freeze({
	help = "Add a GitHub, Jira, hop, or Claude Code source",
	define = function(parser: cli.Parser)
		for _, kind in KIND_ORDER do
			local kindParser = parser:subcommand(kind, { help = KINDS[kind].help })
			kindParser:add("help", "flag", { help = "Show this help", aliases = { "h" } })
			kindParser:add("canvas", "option", { help = "Use this canvas for this command" })
			definitions.tools[kindParser] = KINDS[kind].mcp

			for _, option in getOptions(kind) do
				addArgument(kindParser, option.name, "option", {
					help = option.help,
					type = if option.isCommand then "command" elseif option.isList then "commaList" else nil,
					mcp = if option.isRequired then { required = true } else nil,
				})
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

		local source, command = createSource(kind, readValues(kind, kindParser))
		local isUpdate = false
		local doc = runTransaction(options.dir, function(current)
			for _, existing in current.settings.sources do
				if existing.id == source.id then
					assert(
						existing.kind == source.kind,
						`source id "{source.id}" already names a {existing.kind} source`
					)
					mergeSource(existing, source)
					isUpdate = true
					return
				end
			end

			table.insert(current.settings.sources, source)
		end)

		-- The command goes in this machine's config, never the canvas's files,
		-- which can be shared through git.
		if command then
			setSourceCommand(options.root, options.workspace, source.id, command)
		end

		writeResult(
			options,
			json.object({ revision = doc.revision, id = source.id }),
			if isUpdate then `Updated source {source.id}` else `Added source {source.id}`
		)
	end,
})
