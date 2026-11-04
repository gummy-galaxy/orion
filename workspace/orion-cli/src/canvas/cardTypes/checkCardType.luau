local json = require("@std/json")

local cardTypes = require("@root/canvas/cardTypes/types")

type CardType = cardTypes.CardType
type Field = cardTypes.Field

-- Lowercase, so a type reads the same on the command line and in a file, with
-- dots for a pack's own names, such as figma.frame.
local NAME = "^%l[%l%d%.%-]*$"
local FIELD_NAME = "^%l[%w]*$"

local FIELD_KINDS: { [string]: boolean } = {
	text = true,
	markdown = true,
	number = true,
	choice = true,
	date = true,
	url = true,
	boolean = true,
}
local LAYOUTS: { [string]: boolean } = { card = true, note = true, component = true, image = true }
local MEANINGS: { [string]: boolean } =
	{ todo = true, active = true, review = true, blocked = true, deferred = true, done = true }

local function checkDefault(cardType: CardType, field: Field)
	local value = field.default
	local where = `{cardType.name}'s {field.name} default`

	if value == nil then
		return
	end

	if field.kind == "number" then
		assert(type(value) == "number", `{where} must be a number`)
	elseif field.kind == "boolean" then
		assert(type(value) == "boolean", `{where} must be true or false`)
	else
		assert(type(value) == "string", `{where} must be text`)
	end

	if field.kind == "choice" then
		for _, choice in field.choices or {} do
			if choice.value == value then
				return
			end
		end

		error(`{where} isn't one of its choices`)
	end
end

-- Raises with the reason when a declaration can't be registered, so a pack
-- with a mistake fails when it loads rather than on some card later.
local function checkCardType(cardType: CardType)
	local name = cardType.name
	assert(type(name) == "string" and name:match(NAME), `invalid type name {json.serialize(name :: any)}`)
	assert(type(cardType.label) == "string" and cardType.label ~= "", `{name} needs a label`)
	assert(type(cardType.pack) == "string" and cardType.pack ~= "", `{name} needs a pack`)

	for _, other in cardType.supersedes or {} do
		assert(type(other) == "string" and other:match(NAME) and other ~= name, `{name} supersedes an invalid type`)
	end

	local fieldNames: { [string]: boolean } = {}

	for _, field in cardType.fields do
		assert(type(field.name) == "string" and field.name:match(FIELD_NAME), `{name} has an invalid field name`)
		assert(not fieldNames[field.name], `{name} declares {field.name} twice`)
		assert(type(field.label) == "string" and field.label ~= "", `{name}'s {field.name} needs a label`)
		assert(FIELD_KINDS[field.kind], `{name}'s {field.name} has an unknown kind {field.kind}`)
		assert(
			(field.kind == "choice") == (field.choices ~= nil),
			`{name}'s {field.name} takes choices only when its kind is choice`
		)
		assert(field.choices == nil or #field.choices > 0, `{name}'s {field.name} needs at least one choice`)
		checkDefault(cardType, field)
		fieldNames[field.name] = true
	end

	local face = cardType.face
	assert(LAYOUTS[face.layout], `{name} has an unknown layout {face.layout}`)

	if face.size then
		assert(face.size.width > 0 and face.size.height > 0, `{name}'s size must be positive`)
	end

	for _, shown in face.shows do
		assert(fieldNames[shown], `{name} shows {shown}, which it doesn't declare`)
	end

	local stateNames: { [string]: boolean } = {}

	for _, state in cardType.states do
		assert(type(state.name) == "string" and state.name:match(FIELD_NAME), `{name} has an invalid state name`)
		assert(not stateNames[state.name], `{name} declares the state {state.name} twice`)
		assert(type(state.label) == "string" and state.label ~= "", `{name}'s {state.name} state needs a label`)
		assert(MEANINGS[state.means], `{name}'s {state.name} state has an unknown meaning {state.means}`)
		stateNames[state.name] = true
	end

	local meaning = cardType.meaning
	assert(meaning.doneWhen == "state" or meaning.doneWhen == "inputs", `{name} has an unknown doneWhen`)
	assert(meaning.canBeDone or #cardType.states == 0, `{name} can't be done, so it takes no states`)
	assert(meaning.canBeDone or not meaning.isWork, `{name} is work, so it must be able to be done`)
	assert(
		not meaning.canBeDone or meaning.doneWhen == "inputs" or #cardType.states > 0,
		`{name} is done by its state, so it needs states`
	)
end

return checkCardType
