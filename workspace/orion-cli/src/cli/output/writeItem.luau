local json = require("@std/json")

local context = require("@root/cli/context")
local derive = require("@root/canvas/derive")
local getLabel = require("@root/canvas/items/getLabel")
local render = require("@root/canvas/render")
local types = require("@root/types")

type Context = context.Context
type Doc = types.Doc
type Item = types.Item

-- Reports the item a command added or changed, with the revision it made, as
-- JSON or as one line led by the verb.
local function writeItem(options: Context, doc: Doc, item: Item, verb: string)
	if options.asJson then
		local value = json.object({
			revision = doc.revision,
			item = render.itemJson(doc, derive(doc, options.now()), item),
		})
		options.write(json.serialize(value, true))
	else
		options.write(`{verb} {item.id} · {getLabel(item)}`)
	end
end

return writeItem
