local cli = require("@batteries/cli")
local json = require("@std/json")

local addArgument = require("@root/cli/addArgument")
local compute = require("@root/suggest/compute")
local context = require("@root/cli/context")
local convertToJson = require("@root/suggest/convertToJson")
local loadDoc = require("@root/store/loadDoc")
local parseCommand = require("@root/adapters/parseCommand")
local runTransaction = require("@root/store/runTransaction")
local save = require("@root/suggest/save")

type Context = context.Context

local FALLBACK = "The command failed or returned no valid groups; kept heuristic suggestions."

return table.freeze({
	help = "Compute group suggestions",
	mcp = { annotations = { openWorldHint = true } },
	define = function(parser: cli.Parser)
		addArgument(parser, "command", "option", {
			help = "JSON array naming a command that groups the cards it reads on stdin",
			type = "command",
			mcp = {
				description = 'A command and its arguments, such as ["claude", "-p", "--output-format", "json"]. It reads the cards as a prompt on stdin and replies with JSON groups.',
			},
		})
		addArgument(
			parser,
			"scope",
			"option",
			{ help = "unsorted or all", type = "enum", values = { "unsorted", "all" } }
		)
		parser:add("dry-run", "flag", { help = "Show suggestions without writing" })
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local commandText = parser:get("command")
		local command = if commandText then parseCommand(commandText) else nil
		local current = loadDoc(options.dir)
		local result, didFallback =
			compute(current, parser:get("scope") or "unsorted", command, options.runner, options.now())
		local revision = current.revision

		if not parser:has("dry-run") then
			revision = runTransaction(options.dir, function(doc)
				save(doc, result)
			end).revision
		end

		if options.asJson then
			local value = convertToJson(result)
			value.revision = revision

			if didFallback then
				value.warning = FALLBACK
			end

			options.write(json.serialize(value, true))
		else
			local lines = { `{#result.groups} group suggestions{if parser:has("dry-run") then " (dry run)" else ""}:` }

			for _, group in result.groups do
				table.insert(
					lines,
					`  {group.id}  {group.title}  [{table.concat(group.members, ", ")}] — {group.reason}`
				)
			end

			if didFallback then
				table.insert(lines, FALLBACK)
			end

			options.write(table.concat(lines, "\n"))
		end
	end,
})
