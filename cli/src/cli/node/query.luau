local cli = require("@batteries/cli")
local json = require("@std/json")

local context = require("@root/cli/context")
local getRequired = require("@root/cli/getRequired")
local graph = require("@root/graph")
local pad = require("@root/render/pad")
local render = require("@root/render")
local selectItems = require("@root/query/selectItems")
local store = require("@root/store")
local types = require("@root/types")

type Context = context.Context
type Doc = types.Doc
type Item = types.Item

local function writeJson(options: Context, doc: Doc, derived: graph.Derived, items: { Item })
	local values: json.Array = {}

	for _, item in items do
		local value = render.itemJson(doc, derived, item)

		if graph.isGroup(item) then
			value.kind = "group"
			value.status = nil
			value.recordedStatus = nil
		end

		table.insert(values, value)
	end

	options.write(json.serialize(values, true))
end

local function writeLines(options: Context, doc: Doc, derived: graph.Derived, items: { Item })
	local lines: { string } = {}

	for _, item in items do
		if graph.isGroup(item) or item.type == "image" then
			local kind = if graph.isGroup(item) then "group" else "image"
			local parentItem = if item.parentId then graph.find(doc, item.parentId) else nil
			local where = if parentItem then graph.label(parentItem) else ""
			table.insert(lines, `{pad(kind, 9)}{pad(item.id, 24)}{pad(graph.label(item), 44)}{pad(kind, 20)}{where}`)
		else
			table.insert(lines, render.table(doc, derived, { item }))
		end
	end

	options.write(if #lines > 0 then table.concat(lines, "\n") else "Nothing matches.")
end

return table.freeze({
	help = "Find cards and groups with an expression",
	define = function(parser: cli.Parser)
		parser:add("where", "option", { help = "Expression selecting cards or groups", required = true })
		parser:add("all", "flag", { help = "Include done items" })
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local doc = store.load(options.dir)
		local items = selectItems(doc, getRequired(parser, "where"), parser:has("all"), options.now())
		local derived = graph.derive(doc, options.now())

		if options.asJson then
			writeJson(options, doc, derived, items)
		else
			writeLines(options, doc, derived, items)
		end
	end,
})
