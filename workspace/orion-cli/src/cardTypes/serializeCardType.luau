local json = require("@std/json")

local cardTypes = require("@root/cardTypes/types")

type CardType = cardTypes.CardType

-- A declaration as JSON, the shape orion type show --json prints and the app
-- reads.
local function serializeCardType(cardType: CardType): json.Object
	local fields: json.Array = {}

	for _, field in cardType.fields do
		local value = json.object({ name = field.name, label = field.label, kind = field.kind })

		if field.choices then
			local choices: json.Array = {}

			for _, choice in field.choices do
				table.insert(choices, json.object({ value = choice.value, label = choice.label }))
			end

			value.choices = choices
		end

		value.default = field.default
		table.insert(fields, value)
	end

	local shows: json.Array = {}

	for _, name in cardType.face.shows do
		table.insert(shows, name)
	end

	local face = json.object({ layout = cardType.face.layout, shows = shows })

	if cardType.face.size then
		face.size = json.object({ width = cardType.face.size.width, height = cardType.face.size.height })
	end

	local states: json.Array = {}

	for _, state in cardType.states do
		table.insert(states, json.object({ name = state.name, label = state.label, means = state.means }))
	end

	local meaning = cardType.meaning
	local supersedes: json.Array = {}

	for _, name in cardType.supersedes or {} do
		table.insert(supersedes, name)
	end

	return json.object({
		name = cardType.name,
		label = cardType.label,
		pack = cardType.pack,
		supersedes = supersedes,
		fields = fields,
		face = face,
		states = states,
		meaning = json.object({
			isWork = meaning.isWork,
			canBlock = meaning.canBlock,
			canBeDone = meaning.canBeDone,
			doneWhen = meaning.doneWhen,
		}),
	})
end

return serializeCardType
