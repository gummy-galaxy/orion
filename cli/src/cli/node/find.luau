local cli = require("@batteries/cli")
local json = require("@std/json")

local addArgument = require("@root/cli/addArgument")
local context = require("@root/cli/context")
local findItem = require("@root/graph/findItem")
local findItems = require("@root/query/findItems")
local getLabel = require("@root/graph/getLabel")
local getWorkspaceDir = require("@root/store/getWorkspaceDir")
local getWorkspaces = require("@root/store/getWorkspaces")
local isGroup = require("@root/graph/isGroup")
local joinWords = require("@root/cli/joinWords")
local loadDoc = require("@root/store/loadDoc")
local pad = require("@root/render/pad")
local render = require("@root/render")

type Context = context.Context

local DEFAULT_LIMIT = 20

-- The most matches to print, unless --limit says otherwise.
local function getLimit(parser: cli.Parser): number
	local value = parser:get("limit")

	if value == nil then
		return DEFAULT_LIMIT
	end

	local number = tonumber(value)
	assert(number and number >= 1 and number == math.floor(number), "limit must be a positive whole number")
	return number
end

local function writeJson(options: Context, result: findItems.Result, limit: number)
	local values: json.Array = {}

	for _, hit in result.hits do
		local value = render.itemJson(hit.doc, hit.derived, hit.item)
		value.canvas = hit.name
		table.insert(values, value)
	end

	options.write(json.serialize(json.object({ total = result.total, limit = limit, items = values }), true))
end

local function writeLines(options: Context, result: findItems.Result, showCanvas: boolean)
	local lines: { string } = {}

	for _, hit in result.hits do
		local item = hit.item
		local state = if isGroup(item) then "group" else hit.derived.status[item.id] or "ready"
		local parentItem = if item.parentId then findItem(hit.doc, item.parentId) else nil
		local where = if parentItem then `in {getLabel(parentItem)}` else "top level"
		local canvasColumn = if showCanvas then pad(hit.name, 16) else ""
		table.insert(lines, `{canvasColumn}{pad(item.id, 28)}{pad(getLabel(item), 44)}{pad(state, 10)}{where}`)
	end

	if result.total > #result.hits then
		table.insert(lines, `Showing {#result.hits} of {result.total} matches; narrow the text or raise --limit.`)
	end

	options.write(if #lines > 0 then table.concat(lines, "\n") else "Nothing matches.")
end

return table.freeze({
	help = "Find cards and groups whose label, note, or refs contain text",
	mcp = { annotations = { readOnlyHint = true } },
	define = function(parser: cli.Parser)
		addArgument(parser, "text", "variadic", { help = "Text to find, matched case-insensitively", type = "words" })
		addArgument(parser, "limit", "option", { help = "Most matches to print (default 20)", type = "integer" })
		parser:add("all-canvases", "flag", { help = "Search every canvas, not only this one" })
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local text = joinWords(parser:variadics(), "<text>")
		local limit = getLimit(parser)
		local allCanvases = parser:has("all-canvases")
		local canvases: { findItems.Canvas } = {}

		if allCanvases then
			for _, entry in getWorkspaces(options.root).workspaces do
				local doc = loadDoc(getWorkspaceDir(options.root, entry.name))
				table.insert(canvases, { name = entry.name, doc = doc })
			end
		else
			table.insert(canvases, { name = options.workspace, doc = loadDoc(options.dir) })
		end

		local result = findItems(canvases, text, limit)

		if options.asJson then
			writeJson(options, result, limit)
		else
			writeLines(options, result, allCanvases)
		end
	end,
})
