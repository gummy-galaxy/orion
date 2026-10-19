local cli = require("@batteries/cli")
local json = require("@std/json")

local addArgument = require("@root/cli/addArgument")
local compute = require("@root/suggest/compute")
local context = require("@root/cli/context")
local convertToJson = require("@root/suggest/convertToJson")
local loadDoc = require("@root/store/loadDoc")
local runTransaction = require("@root/store/runTransaction")
local save = require("@root/suggest/save")

type Context = context.Context

return table.freeze({
	help = "Compute group suggestions",
	mcp = { annotations = { openWorldHint = true } },
	define = function(parser: cli.Parser)
		addArgument(
			parser,
			"agent",
			"option",
			{ help = "claude, codex, or none", type = "enum", values = { "claude", "codex", "none" } }
		)
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
		local current = loadDoc(options.dir)
		local settings = if current.raw then json.asObject(current.raw.settings) else nil
		local configured = if settings and type(settings.agent) == "string" then settings.agent else nil
		local agent = parser:get("agent") or configured or "none"
		local result, didFallback =
			compute(current, parser:get("scope") or "unsorted", agent, options.runner, options.now())
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
				value.warning = "Agent unavailable or returned no valid groups; kept heuristic suggestions."
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
				table.insert(lines, "Agent unavailable or returned no valid groups; kept heuristic suggestions.")
			end

			options.write(table.concat(lines, "\n"))
		end
	end,
})
