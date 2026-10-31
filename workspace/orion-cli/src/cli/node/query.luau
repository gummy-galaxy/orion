local cli = require("@batteries/cli")
local json = require("@std/json")

local addArgument = require("@root/cli/addArgument")
local context = require("@root/cli/context")
local findItem = require("@root/graph/findItem")
local formatList = require("@root/render/formatList")
local getLabel = require("@root/graph/getLabel")
local getRequired = require("@root/cli/getRequired")
local graphTypes = require("@root/graph/types")
local isGroup = require("@root/graph/isGroup")
local loadDoc = require("@root/store/loadDoc")
local pad = require("@root/render/pad")
local parseLimit = require("@root/cli/parseLimit")
local parseSort = require("@root/query/parseSort")
local queryItems = require("@root/query/queryItems")
local querySyntax = require("@root/query/querySyntax")
local queryTypes = require("@root/query/types")
local render = require("@root/render")
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

local function writeLines(options: Context, doc: Doc, result: queryTypes.Result)
	local derived = result.derived
	local lines: { string } = {}

	for _, item in result.items do
		if isGroup(item) or item.type == "image" then
			local kind = if isGroup(item) then "group" else "image"
			local parentItem = if item.parentId then findItem(doc, item.parentId) else nil
			local where = if parentItem then getLabel(parentItem) else ""
			table.insert(lines, `{pad(kind, 9)}{pad(item.id, 38)}{pad(getLabel(item), 44)}{pad(kind, 20)}{where}`)
		else
			table.insert(lines, render.table(doc, derived, { item }))
		end
	end

	if #result.items < result.total then
		local first, last = result.offset + 1, result.offset + #result.items
		local range = if #result.items == 0 then "none" elseif first == last then `{first}` else `{first}–{last}`
		table.insert(lines, `Showing {range} of {result.total} matches.`)
	end

	options.write(if #lines > 0 then table.concat(lines, "\n") else "Nothing matches.")
end

return table.freeze({
	help = "Find cards and groups with an expression",
	mcp = {
		description = `Find cards and groups with an expression. Fields: {FIELD_NAMES}. `
			.. `Compare quoted values with = or !=, quoting numbers and booleans too; `
			.. `{TEXT_FIELD_NAMES} also take ~ for case-insensitive text.`,
		annotations = { readOnlyHint = true },
	},
	define = function(parser: cli.Parser)
		addArgument(
			parser,
			"where",
			"option",
			{ help = "Expression selecting cards or groups (required)", mcp = { required = true } }
		)
		addArgument(parser, "sort", "option", {
			help = "Fields to sort by, separated by commas, such as status,-label; a leading - sorts descending",
		})
		addArgument(
			parser,
			"offset",
			"option",
			{ help = "Matches to skip before printing", type = "integer", minimum = 0 }
		)
		addArgument(parser, "limit", "option", { help = "Most matches to print", type = "integer", minimum = 1 })
		parser:add("all", "flag", { help = "Include done items" })
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local doc = loadDoc(options.dir)
		local sort = parser:get("sort")
		local offset = parser:get("offset")
		local result = queryItems(doc, {
			where = getRequired(parser, "where"),
			sort = if sort then parseSort(sort) else nil,
			offset = if offset then assert(tonumber(offset), "offset must be a whole number") else nil,
			limit = parseLimit(parser:get("limit")),
			includeDone = parser:has("all"),
			now = options.now(),
		})

		if options.asJson then
			writeJson(options, doc, result.derived, result.items)
		else
			writeLines(options, doc, result)
		end
	end,
})
