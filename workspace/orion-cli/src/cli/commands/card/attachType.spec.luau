local json = require("@std/json")
local test = require("@std/test")

local loadDoc = require("@root/storage/canvases/loadDoc")
local testing = require("@root/testing")
local writeDoc = require("@root/storage/canvases/writeDoc")

test.case("card types and card type-show describe the registered types", function(assert)
	local dir = testing.directory("type-list")
	writeDoc(dir, testing.createDoc({}))

	local listed = json.asArray(json.deserialize(testing.run(dir, { "card", "types", "--json" }))) :: json.Array
	local names: { string } = {}

	for _, value in listed do
		table.insert(names, (json.asObject(value) :: json.Object).name :: string)
	end

	assert.eq(table.concat(names, ","), "step,pr,placeholder,gate,note,component,image")

	local gate =
		json.asObject(json.deserialize(testing.run(dir, { "card", "type-show", "gate", "--json" }))) :: json.Object
	assert.eq((json.asObject(gate.meaning) :: json.Object).doneWhen, "inputs")
	assert.strContains(testing.run(dir, { "card", "type-show", "note" }), "done: when its inputs are")
end)

test.case("card attach-type and card detach-type change the types a person gave a card", function(assert)
	local dir = testing.directory("type-attach")
	writeDoc(dir, testing.createDoc({ testing.task("a", "A", "todo") }))

	testing.run(dir, { "card", "attach-type", "a", "gate" })
	local shown = json.asObject(json.deserialize(testing.run(dir, { "node", "show", "a", "--json" }))) :: json.Object
	assert.eq(table.concat(shown.types :: any, ","), "step,gate")

	testing.run(dir, { "card", "detach-type", "a", "gate" })
	assert.eq(loadDoc(dir).nodes[1].data.types, nil)
end)

test.case("node query matches any type a card carries", function(assert)
	local dir = testing.directory("type-query")
	writeDoc(
		dir,
		testing.createDoc({
			testing.task("a", "A", "todo", nil, { types = { "gate" } }),
			testing.task("b", "B", "todo"),
		})
	)

	local found = testing.run(dir, { "node", "query", "--where", 'type = "gate"', "--json" })
	assert.strContains(found, '"a"')
	assert.eq(found:find('"b"', 1, true), nil)
end)

test.case("card set --field sets a field the card's types declare, and node show lists it", function(assert)
	testing.withCardTypes({
		{
			name = "figma.frame",
			label = "Figma frame",
			pack = "figma",
			fields = {
				{
					name = "stage",
					label = "Stage",
					kind = "choice",
					choices = { { value = "draft", label = "Draft" }, { value = "final", label = "Final" } },
					default = "draft",
				},
			},
			face = { layout = "card", shows = { "stage" } },
			states = { { name = "approved", label = "Approved", means = "done" } },
			meaning = { isWork = true, canBlock = true, canBeDone = true, doneWhen = "state" },
		},
	}, function()
		local dir = testing.directory("type-field")
		writeDoc(dir, testing.createDoc({ testing.task("a", "A", "todo", nil, { types = { "figma.frame" } }) }))

		local function shownFields(): json.Object
			local shown =
				json.asObject(json.deserialize(testing.run(dir, { "node", "show", "a", "--json" }))) :: json.Object
			return json.asObject(shown.fields) :: json.Object
		end

		assert.eq(shownFields().stage, "draft")
		testing.run(dir, { "card", "set", "a", "--field", "stage=final" })
		assert.eq(shownFields().stage, "final")
	end)
end)
