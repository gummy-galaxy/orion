local cli = require("@batteries/cli")
local json = require("@std/json")

local context = require("@root/cli/context")
local findCardType = require("@root/canvas/cardTypes/findCardType")
local getRequired = require("@root/cli/arguments/getRequired")
local serializeCardType = require("@root/canvas/cardTypes/serializeCardType")

type Context = context.Context

return table.freeze({
	help = "Show a card type's fields, face, states, and meaning",
	mcp = { annotations = { readOnlyHint = true } },
	define = function(parser: cli.Parser)
		parser:add("name", "positional", { help = "The type's name, such as gate" })
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local name = getRequired(parser, "name")
		local cardType = assert(findCardType(name), `no type named {name}; orion card types shows them`)

		if parser:has("json") then
			options.write(json.serialize(serializeCardType(cardType), true))
			return
		end

		local meaning = cardType.meaning
		local lines = { `{cardType.name}  {cardType.label}  ({cardType.pack})`, `face: {cardType.face.layout}` }

		for _, field in cardType.fields do
			table.insert(lines, `field {field.name}: {field.label} ({field.kind})`)
		end

		for _, state in cardType.states do
			table.insert(lines, `state {state.name}: {state.label}, counts as {state.means}`)
		end

		local isWork = if meaning.isWork then "yes" else "no"
		local canBlock = if meaning.canBlock then "yes" else "no"
		local doneWhen = if not meaning.canBeDone
			then "never"
			elseif meaning.doneWhen == "inputs" then "when its inputs are"
			else "by its state"
		table.insert(lines, `work: {isWork} · blocks: {canBlock} · done: {doneWhen}`)
		options.write(table.concat(lines, "\n"))
	end,
})
