local json = require("@std/json")

local context = require("@root/cli/context")
local derive = require("@root/graph/derive")
local getLabel = require("@root/graph/getLabel")
local render = require("@root/render")
local types = require("@root/types")

type Context = context.Context
type Doc = types.Doc
type Item = types.Item

-- Reports the item a command added or changed, as JSON or as one line led by the verb.
local function writeItem(options: Context, doc: Doc, item: Item, verb: string)
	if options.asJson then
		options.write(json.serialize(render.itemJson(doc, derive(doc, options.now()), item), true))
	else
		options.write(`{verb} {item.id} · {getLabel(item)}`)
	end
end

return writeItem
