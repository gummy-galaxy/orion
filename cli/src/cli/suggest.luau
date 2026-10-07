local batteriesCli = require("@batteries/cli")
local json = require("@std/json")

local context = require("@root/cli/context")
local store = require("@root/store")
local suggest = require("@root/suggest")

type Context = context.Context

return table.freeze({
	help = "Compute group suggestions",
	define = function(parser: batteriesCli.Parser)
		parser:add("agent", "option", { help = "claude, codex, or none" })
		parser:add("scope", "option", { help = "unsorted or all" })
		parser:add("dry-run", "flag", { help = "Show suggestions without writing" })
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: batteriesCli.Parser, options: Context)
		local current = store.load(options.directory)
		local settings = if current.raw then json.asObject(current.raw.settings) else nil
		local configured = if settings and type(settings.agent) == "string" then settings.agent else nil
		local agent = parser:get("agent") or configured or "none"
		local result, didFallback =
			suggest.compute(current, parser:get("scope") or "unsorted", agent, options.runner, options.now())
		if not parser:has("dry-run") then
			store.transaction(options.directory, function(doc)
				suggest.save(doc, result)
			end)
		end

		if options.asJson then
			local value = suggest.convertToJson(result)

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
