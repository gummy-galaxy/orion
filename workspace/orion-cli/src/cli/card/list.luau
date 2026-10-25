local cli = require("@batteries/cli")

local addArgument = require("@root/cli/addArgument")
local context = require("@root/cli/context")
local derive = require("@root/graph/derive")
local getAncestors = require("@root/graph/getAncestors")
local getGroup = require("@root/graph/getGroup")
local loadDoc = require("@root/store/loadDoc")
local resolveId = require("@root/query/resolveId")
local sortTasks = require("@root/cli/sortTasks")
local types = require("@root/types")
local writeItems = require("@root/cli/writeItems")

type Context = context.Context
type Doc = types.Doc
type Item = types.Item

local function isInsideGroup(doc: Doc, item: Item, groupId: string): boolean
	return table.find(getAncestors(doc, item.id), groupId) ~= nil
end

return table.freeze({
	help = "List work items with their derived status",
	mcp = { annotations = { readOnlyHint = true } },
	define = function(parser: cli.Parser)
		addArgument(parser, "group", "option", { help = "Only items inside this group", type = "id" })
		parser:add("all", "flag", { help = "Include done items" })
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local doc = loadDoc(options.dir)
		local derived = derive(doc, options.now())
		local groupId = parser:get("group")

		if groupId then
			groupId = resolveId(doc, groupId)
			getGroup(doc, groupId)
		end

		local all = parser:has("all")
		local items = sortTasks(doc, derived, function(item)
			return (all or derived.status[item.id] ~= "done") and (groupId == nil or isInsideGroup(doc, item, groupId))
		end)

		writeItems(options, doc, derived, items)
	end,
})
