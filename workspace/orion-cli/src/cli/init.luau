local cli = require("@batteries/cli")
local process = require("@std/process")

local aliasEntries = require("@root/cli/aliases/entries")
local aliasTypes = require("@root/cli/aliases/types")
local apply = require("@root/cli/commands/apply")
local backup = require("@root/cli/commands/backup")
local canvas = require("@root/cli/commands/canvas")
local card = require("@root/cli/commands/card")
local ci = require("@root/cli/commands/ci")
local context = require("@root/cli/context")
local defaultRun = require("@root/common/process/command")
local definitions = require("@root/cli/definitions")
local describeCommands = require("@root/cli/describeCommands")
local focus = require("@root/cli/commands/focus")
local formatAllHelp = require("@root/cli/formatAllHelp")
local formatList = require("@root/common/text/formatList")
local fs = require("@std/fs")
local getActiveWorkspace = require("@root/storage/canvases/getActiveWorkspace")
local getDataRoot = require("@root/storage/getDataRoot")
local getVersion = require("@root/common/getVersion")
local getWorkspaceDir = require("@root/storage/canvases/getWorkspaceDir")
local group = require("@root/cli/commands/group")
local ingest = require("@root/cli/commands/ingest")
local json = require("@std/json")
local link = require("@root/cli/commands/link")
local log = require("@root/cli/commands/log")
local mcp = require("@root/cli/commands/mcp")
local media = require("@root/cli/commands/media")
local nextCommand = require("@root/cli/commands/next")
local node = require("@root/cli/commands/node")
local note = require("@root/cli/commands/note")
local orientation = require("@root/cli/orientation")
local querySyntax = require("@root/canvas/query/querySyntax")
local ref = require("@root/cli/commands/ref")
local reportFailure = require("@root/cli/output/reportFailure")
local resolveArguments = require("@root/cli/aliases/resolveArguments")
local reveal = require("@root/cli/commands/reveal")
local serializeCommands = require("@root/cli/serializeCommands")
local server = require("@root/cli/commands/server")
local source = require("@root/cli/commands/source")
local suggestion = require("@root/cli/commands/suggestion")
local telemetry = require("@root/cli/commands/telemetry")
local theme = require("@root/cli/commands/theme")
local types = require("@root/types")

type Context = context.Context
type Command = context.Command

export type Dependencies = context.Dependencies

type Resolved = {
	runner: types.CommandRunner,
	write: (string) -> (),
	warn: (string) -> (),
	aliases: { aliasTypes.Alias },
	dataDir: string,
	workspace: string?,
	now: () -> string,
	exit: (code: number) -> (),
}

local SUMMARY = "orion — keep a graph of work up to date from the command line"

-- Each top-level command's module defines its subcommands and runs them.
local COMMANDS: { [string]: Command } = {
	apply = apply,
	backup = backup,
	canvas = canvas,
	card = card,
	ci = ci,
	focus = focus,
	group = group,
	ingest = ingest,
	link = link,
	log = log,
	mcp = mcp,
	media = media,
	next = nextCommand,
	node = node,
	note = note,
	ref = ref,
	reveal = reveal,
	server = server,
	source = source,
	suggestion = suggestion,
	telemetry = telemetry,
	theme = theme,
}

-- The order orion --help lists them in.
local COMMAND_ORDER = {
	"card",
	"note",
	"link",
	"node",
	"group",
	"ref",
	"next",
	"apply",
	"canvas",
	"log",
	"server",
	"source",
	"ingest",
	"media",
	"suggestion",
	"ci",
	"theme",
	"backup",
	"telemetry",
	"mcp",
	"focus",
	"reveal",
}

local ABOUT = [[
Statuses: todo, active, review, blocked, deferred, done.
  Listed statuses are derived: todo shows as ready once nothing it waits on is open,
  and as blocked while something is. Notes pass blocking through and never count as work.
Components (card create --kind component) draw a system: services, apps, and data stores linked
  by what flows between them (link create --label). They have no status and never count as work.
Repositories are "owner/name".
Items and groups take an id, or a selector that must match exactly one: label:"text", ref:key or URL, or pr:number.
Data lives in Orion's user data folder (run orion canvas path to see it); set ORION_DATA_DIR to change it.
Set ORION_CANVAS to pick a canvas, as --canvas does for a single command.
Set DO_NOT_TRACK=1 or ORION_TELEMETRY=0 to never send usage data; orion telemetry status shows the choice.
The Orion app talks to orion server start, which watches the data files.
Use orion server status [--json] to find the running server.
While the app is open, orion focus shows its open group and selection, and orion reveal selects items
  in it and zooms to them.]]

local QUERY_HELP = table.concat({
	`Fields: {table.concat(querySyntax.fieldNames, ", ")}.`,
	'status is the derived status; snoozed is "true" while a card is snoozed and "false" otherwise.',
	'Compare quoted values with = or !=, quoting numbers and booleans too: pr = "86", draft = "true".',
	`{formatList(querySyntax.textFieldNames)} also support ~ for case-insensitive text.`,
	"Combine with and, or, not, and parentheses. Missing fields never match.",
	"--sort takes fields separated by commas, such as status,-pr; a leading - sorts descending.",
}, "\n")

local function addHelpFlag(parser: cli.Parser)
	parser:add("help", "flag", { help = "Show this help", aliases = { "h" } })
end

local function addCanvasOption(parser: cli.Parser)
	parser:add("canvas", "option", { help = "Use this canvas for this command" })
end

-- Every command takes --json. Commands with JSON output define the flag
-- themselves, and this adds it to the rest. That way any command run with
-- --json reports a failure as JSON, even one with no JSON output of its own.
local function addJsonFlags(parser: cli.Parser)
	if #parser.commands > 0 then
		for _, command in parser.commands do
			addJsonFlags(command.parser)
		end

		return
	end

	for _, argument in parser.arguments do
		if argument.name == "json" then
			return
		end
	end

	parser:add("json", "flag", { help = "Print JSON" })
end

type Parsers = {
	root: cli.Parser,
	commands: { [string]: cli.Parser },
}

local function createParsers(): Parsers
	local root = cli.parser()
	addHelpFlag(root)
	root:add("version", "flag", { help = "Print the Orion version and build commit" })
	addCanvasOption(root)
	local commands: { [string]: cli.Parser } = {}

	-- Every command takes the help flag and --canvas option, then defines the
	-- rest itself.
	local function addCommand(name: string, help: string): cli.Parser
		local parser = root:subcommand(name, { help = help })
		addHelpFlag(parser)
		addCanvasOption(parser)
		return parser
	end

	for _, name in COMMAND_ORDER do
		local module = COMMANDS[name]
		local parser = addCommand(name, module.help)
		commands[name] = parser
		definitions.tools[parser] = module.mcp
		module.define(parser)
	end

	local helpCommand = addCommand("help", "Show help for Orion or one of its commands")
	definitions.tools[helpCommand] = { skip = "prints help text, which MCP clients already get from tools/list" }
	helpCommand:add("command", "variadic", { help = "Command to describe, such as card list" })
	helpCommand:add("all", "flag", { help = "Describe every command and its options in one listing" })
	helpCommand:add("json", "flag", { help = "Print the command descriptions as JSON" })
	addJsonFlags(root)

	return { root = root, commands = commands }
end

local function rootHelp(parser: cli.Parser): string
	return table.concat({
		SUMMARY,
		"",
		table.concat(orientation.help, "\n\n"),
		"",
		parser:usage("orion"),
		"",
		parser:help(),
		"",
		ABOUT,
	}, "\n")
end

-- Notes that only fit under one command, printed with its help.
local DETAILS: formatAllHelp.Details = {
	["orion node query"] = QUERY_HELP,
}

-- Everything orion help prints, with every command and its options in place of
-- the top-level list.
local function allHelp(parser: cli.Parser): string
	return table.concat({
		SUMMARY,
		"",
		table.concat(orientation.help, "\n\n"),
		"",
		ABOUT,
		"",
		"Every command also takes --canvas <value> to work on that canvas and --help (-h) to show its help.",
		"",
		formatAllHelp(describeCommands(parser, "orion", SUMMARY), DETAILS),
	}, "\n")
end

-- Finds the parser for a command path such as {"card", "list"}, along with the
-- help its parent lists for it.
local function findCommand(root: cli.Parser, names: { string }): (cli.Parser?, string?)
	local current = root
	local help: string? = nil

	for _, name in names do
		local parser: cli.Parser? = nil

		for _, command in current.commands do
			if command.name == name then
				parser = command.parser
				help = command.options.help
			end
		end

		if parser == nil then
			return nil, nil
		end

		current = parser
	end

	return current, help
end

local function commandHelp(name: string, help: string?, parser: cli.Parser): string
	local detail = DETAILS[`orion {name}`]
	local syntax = if detail then `\n\n{detail}` else ""
	return `{help or ""}\n\n{parser:usage(`orion {name}`)}\n\n{parser:help()}{syntax}`
end

-- `orion card list --help` shows help for `card list`, but `--help` could sit
-- on any command along the path. This finds the outermost command that has it
-- and returns that command's help, or nil when none does.
local function helpFor(root: cli.Parser, names: { string }): string?
	for depth = 1, #names do
		local path = table.move(names, 1, depth, 1, {})
		local parser, help = findCommand(root, path)

		if parser and parser:has("help") then
			return commandHelp(table.concat(path, " "), help, parser)
		end
	end

	return nil
end

-- Walks the chosen commands from the root down, returning their names and the
-- deepest parser.
local function selectedPath(root: cli.Parser): ({ string }, cli.Parser)
	local names: { string } = {}
	local current = root

	while true do
		local name, child = current:selected()

		if not (name and child) then
			return names, current
		end

		table.insert(names, name)
		current = child
	end
end

-- The io library in Lute, the runtime the CLI runs on, only writes to stdout.
-- Notices go to stderr through its device file instead, so they never mix into
-- --json output. Windows has no such file, so there the notice is dropped.
local function writeStderr(line: string)
	local opened, handle = pcall(fs.open, "/dev/stderr", "a")

	if opened then
		pcall(fs.write, handle, line .. "\n")
		fs.close(handle)
	end
end

local function dependencies(options: Dependencies?): Resolved
	local given: Dependencies = options or {}
	return {
		runner = given.runner or defaultRun,
		write = given.write or print,
		warn = given.warn or writeStderr,
		aliases = given.aliases or aliasEntries,
		dataDir = given.dataDir or getDataRoot(),
		workspace = if given.workspace == nil then process.env.ORION_CANVAS else given.workspace,
		now = given.now or function()
			return os.date("!%Y-%m-%dT%H:%M:%SZ") :: string
		end,
		exit = given.exit or function(code: number)
			process.exit(code)
		end,
	}
end

-- The canvas comes from the root or the deepest subcommand that names one.
local function requestedCanvas(root: cli.Parser): string?
	local selected: string? = nil
	local current: cli.Parser? = root

	while current do
		selected = current:get("canvas") or selected
		local _, child = current:selected()
		current = child
	end

	return selected
end

-- Describes every command and option, for the generated reference in docs/ and
-- the MCP tools.
local function describe(): describeCommands.CommandDescription
	return describeCommands(createParsers().root, "orion", SUMMARY)
end

local function execute(args: { string }, options: Dependencies?)
	local parsers = createParsers()
	local deps = dependencies(options)
	local resolved, notices = resolveArguments(args, parsers.root, deps.aliases)

	for _, notice in notices do
		deps.warn(notice)
	end

	parsers.root:parse(resolved)
	local names, parser = selectedPath(parsers.root)
	local command = names[1]

	if parsers.root:has("version") then
		deps.write(`orion {getVersion()}`)
		return
	end

	if command == nil or parsers.root:has("help") then
		deps.write(rootHelp(parsers.root))
		return
	end

	if command == "help" then
		local topic = parser:variadics()

		if parser:has("all") then
			assert(#topic == 0, "help --all describes every command, so leave out the command name")
		end

		if #topic == 0 then
			if parser:has("json") then
				deps.write(json.serialize(serializeCommands(describeCommands(parsers.root, "orion", SUMMARY)), true))
			elseif parser:has("all") then
				deps.write(allHelp(parsers.root))
			else
				deps.write(rootHelp(parsers.root))
			end

			return
		end

		local topicParser, topicHelp = findCommand(parsers.root, topic)
		local name = table.concat(topic, " ")
		local found = assert(topicParser, `unknown command: {name}`)

		if parser:has("json") then
			deps.write(
				json.serialize(serializeCommands(describeCommands(found, `orion {name}`, topicHelp or "")), true)
			)
		else
			deps.write(commandHelp(name, topicHelp, found))
		end

		return
	end

	local helpText = helpFor(parsers.root, names)

	if helpText then
		deps.write(helpText)
		return
	end

	local root = deps.dataDir
	local selected = requestedCanvas(parsers.root)
	local active = getActiveWorkspace(root, selected, deps.workspace)

	local commandContext: Context = {
		dir = getWorkspaceDir(root, active),
		root = root,
		workspace = active,
		requestedWorkspace = selected,
		write = deps.write,
		asJson = parser:has("json"),
		runner = deps.runner,
		now = deps.now,
		exit = deps.exit,
		execute = execute,
		describe = describe,
	}

	COMMANDS[command].run(assert(parsers.commands[command], `unknown command: {command}`), commandContext)
end

-- Lute passes the program path as the first argument.
local function run(argv: { string })
	local args = { table.unpack(argv, 2) }
	local succeeded, message = pcall(execute, args, nil)

	if not succeeded then
		reportFailure(args, message, print, writeStderr)
		process.exit(1)
	end
end

return table.freeze({
	describe = describe,
	execute = execute,
	run = run,
})
