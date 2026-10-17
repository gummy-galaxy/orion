local cli = require("@batteries/cli")
local json = require("@std/json")

local checkLayout = require("@root/layout/checkLayout")
local context = require("@root/cli/context")
local layoutTypes = require("@root/layout/types")
local pad = require("@root/render/pad")
local store = require("@root/store")

type Context = context.Context
type Issue = layoutTypes.Issue

local function describe(issue: Issue): string
	local ids = table.concat(issue.ids, ", ")
	local bounds = issue.bounds

	if bounds == nil then
		return `{pad(issue.kind, 20)}{ids}`
	end

	return `{pad(issue.kind, 20)}{ids}  at {bounds.x}, {bounds.y} · {bounds.width} × {bounds.height}`
end

local function serialize(issue: Issue): json.Object
	local ids: json.Array = {}

	for _, id in issue.ids do
		table.insert(ids, id)
	end

	local bounds = issue.bounds
	local value = if bounds
		then json.object({ x = bounds.x, y = bounds.y, width = bounds.width, height = bounds.height })
		else json.null

	return json.object({ kind = issue.kind, ids = ids, bounds = value })
end

return table.freeze({
	help = "Report layout problems: overlaps, items outside their group, dangling links, and groups waiting for layout",
	define = function(parser: cli.Parser)
		parser:add("group", "option", { help = "Only problems in this group or inside it" })
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local issues = checkLayout(store.load(options.dir), parser:get("group"))

		if options.asJson then
			local values: json.Array = {}

			for _, issue in issues do
				table.insert(values, serialize(issue))
			end

			options.write(json.serialize(values, true))
		elseif #issues == 0 then
			options.write("No layout problems found.")
		else
			local lines: { string } = {}

			for _, issue in issues do
				table.insert(lines, describe(issue))
			end

			options.write(table.concat(lines, "\n"))
		end

		if #issues > 0 then
			options.exit(1)
		end
	end,
})
