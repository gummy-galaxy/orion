local json = require("@std/json")

local context = require("@root/cli/context")
local graphTypes = require("@root/canvas/types")
local render = require("@root/canvas/render")
local types = require("@root/types")

type Context = context.Context
type Doc = types.Doc
type Item = types.Item

-- Lists items as a JSON array or as the table orion card list prints.
local function writeItems(options: Context, doc: Doc, derived: graphTypes.Derived, items: { Item })
	if options.asJson then
		local values: json.Array = {}

		for _, item in items do
			table.insert(values, render.itemJson(doc, derived, item))
		end

		options.write(json.serialize(values, true))
	else
		options.write(render.table(doc, derived, items))
	end
end

return writeItems
