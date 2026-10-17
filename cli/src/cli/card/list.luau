local cli = require("@batteries/cli")

local context = require("@root/cli/context")
local graph = require("@root/graph")
local sortTasks = require("@root/cli/sortTasks")
local store = require("@root/store")
local types = require("@root/types")
local writeItems = require("@root/cli/writeItems")

type Context = context.Context
type Doc = types.Doc
type Item = types.Item

local function isInsideGroup(doc: Doc, item: Item, groupId: string): boolean
	return table.find(graph.ancestors(doc, item.id), groupId) ~= nil
end

return table.freeze({
	help = "List work items with their derived status",
	define = function(parser: cli.Parser)
		parser:add("group", "option", { help = "Only items inside this group" })
		parser:add("all", "flag", { help = "Include done items" })
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local doc = store.load(options.dir)
		local derived = graph.derive(doc)
		local groupId = parser:get("group")

		if groupId then
			graph.group(doc, groupId)
		end

		local all = parser:has("all")
		local items = sortTasks(doc, derived, function(item)
			return (all or derived.status[item.id] ~= "done") and (groupId == nil or isInsideGroup(doc, item, groupId))
		end)

		writeItems(options, doc, derived, items)
	end,
})
