local cli = require("@batteries/cli")
local json = require("@std/json")

local context = require("@root/cli/context")
local findItems = require("@root/query/findItems")
local getQueryValue = require("@root/cli/getQueryValue")
local graph = require("@root/graph")
local joinWords = require("@root/cli/joinWords")
local pad = require("@root/render/pad")
local store = require("@root/store")

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
		local value = getQueryValue(hit.doc, hit.derived, hit.item)
		value.canvas = hit.name
		table.insert(values, value)
	end

	options.write(json.serialize(json.object({ total = result.total, limit = limit, items = values }), true))
end

local function writeLines(options: Context, result: findItems.Result, showCanvas: boolean)
	local lines: { string } = {}

	for _, hit in result.hits do
		local item = hit.item
		local state = if graph.isGroup(item) then "group" else hit.derived.status[item.id] or "ready"
		local parentItem = if item.parentId then graph.find(hit.doc, item.parentId) else nil
		local where = if parentItem then `in {graph.label(parentItem)}` else "top level"
		local canvasColumn = if showCanvas then pad(hit.name, 16) else ""
		table.insert(lines, `{canvasColumn}{pad(item.id, 28)}{pad(graph.label(item), 44)}{pad(state, 10)}{where}`)
	end

	if result.total > #result.hits then
		table.insert(lines, `Showing {#result.hits} of {result.total} matches; narrow the text or raise --limit.`)
	end

	options.write(if #lines > 0 then table.concat(lines, "\n") else "Nothing matches.")
end

return table.freeze({
	help = "Find cards and groups whose label, note, or refs contain text",
	define = function(parser: cli.Parser)
		parser:add("text", "variadic", { help = "Text to find, matched case-insensitively" })
		parser:add("limit", "option", { help = "Most matches to print (default 20)" })
		parser:add("all-canvases", "flag", { help = "Search every canvas, not only this one" })
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local text = joinWords(parser:variadics(), "<text>")
		local limit = getLimit(parser)
		local allCanvases = parser:has("all-canvases")
		local canvases: { findItems.Canvas } = {}

		if allCanvases then
			for _, entry in store.getWorkspaces(options.root).workspaces do
				local doc = store.load(store.getWorkspaceDir(options.root, entry.name))
				table.insert(canvases, { name = entry.name, doc = doc })
			end
		else
			table.insert(canvases, { name = options.workspace, doc = store.load(options.dir) })
		end

		local result = findItems(canvases, text, limit)

		if options.asJson then
			writeJson(options, result, limit)
		else
			writeLines(options, result, allCanvases)
		end
	end,
})
