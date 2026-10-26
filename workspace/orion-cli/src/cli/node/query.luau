local cli = require("@batteries/cli")
local json = require("@std/json")

local addArgument = require("@root/cli/addArgument")
local context = require("@root/cli/context")
local derive = require("@root/graph/derive")
local findItem = require("@root/graph/findItem")
local formatList = require("@root/render/formatList")
local getLabel = require("@root/graph/getLabel")
local getRequired = require("@root/cli/getRequired")
local graphTypes = require("@root/graph/types")
local isGroup = require("@root/graph/isGroup")
local loadDoc = require("@root/store/loadDoc")
local pad = require("@root/render/pad")
local querySyntax = require("@root/query/querySyntax")
local render = require("@root/render")
local selectItems = require("@root/query/selectItems")
local types = require("@root/types")

type Context = context.Context
type Doc = types.Doc
type Item = types.Item

local FIELD_NAMES = table.concat(querySyntax.fieldNames, ", ")
local TEXT_FIELD_NAMES = formatList(querySyntax.textFieldNames)

local function writeJson(options: Context, doc: Doc, derived: graphTypes.Derived, items: { Item })
	local values: json.Array = {}

	for _, item in items do
		table.insert(values, render.itemJson(doc, derived, item))
	end

	options.write(json.serialize(values, true))
end

local function writeLines(options: Context, doc: Doc, derived: graphTypes.Derived, items: { Item })
	local lines: { string } = {}

	for _, item in items do
		if isGroup(item) or item.type == "image" then
			local kind = if isGroup(item) then "group" else "image"
			local parentItem = if item.parentId then findItem(doc, item.parentId) else nil
			local where = if parentItem then getLabel(parentItem) else ""
			table.insert(lines, `{pad(kind, 9)}{pad(item.id, 38)}{pad(getLabel(item), 44)}{pad(kind, 20)}{where}`)
		else
			table.insert(lines, render.table(doc, derived, { item }))
		end
	end

	options.write(if #lines > 0 then table.concat(lines, "\n") else "Nothing matches.")
end

return table.freeze({
	help = "Find cards and groups with an expression",
	mcp = {
		description = `Find cards and groups with an expression. Fields: {FIELD_NAMES}. Compare quoted values with = or !=, quoting numbers and booleans too; {TEXT_FIELD_NAMES} also take ~ for case-insensitive text.`,
		annotations = { readOnlyHint = true },
	},
	define = function(parser: cli.Parser)
		addArgument(
			parser,
			"where",
			"option",
			{ help = "Expression selecting cards or groups (required)", mcp = { required = true } }
		)
		parser:add("all", "flag", { help = "Include done items" })
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local doc = loadDoc(options.dir)
		local items = selectItems(doc, getRequired(parser, "where"), parser:has("all"), options.now())
		local derived = derive(doc, options.now())

		if options.asJson then
			writeJson(options, doc, derived, items)
		else
			writeLines(options, doc, derived, items)
		end
	end,
})
