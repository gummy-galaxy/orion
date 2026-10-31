local cli = require("@batteries/cli")
local json = require("@std/json")

local addArgument = require("@root/cli/arguments/addArgument")
local computeAsync = require("@root/canvas/suggestions/computeAsync")
local context = require("@root/cli/context")
local convertToJson = require("@root/canvas/suggestions/convertToJson")
local loadDoc = require("@root/storage/canvases/loadDoc")
local parseCommand = require("@root/sources/parseCommand")
local runTransaction = require("@root/storage/transactions/runTransaction")
local save = require("@root/canvas/suggestions/save")

type Context = context.Context

local FALLBACK = "The command failed or returned no valid groups; kept heuristic suggestions."

return table.freeze({
	help = "Compute group suggestions",
	mcp = { omit = { { option = "command", reason = "runs a program, which only a person at the CLI should choose" } } },
	define = function(parser: cli.Parser)
		addArgument(parser, "command", "option", {
			help = "JSON array naming a command that groups the cards it reads on stdin",
			type = "command",
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
			computeAsync(current, parser:get("scope") or "unsorted", command, options.runner, options.now())
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
