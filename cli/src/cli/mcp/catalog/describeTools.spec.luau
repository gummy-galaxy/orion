local json = require("@std/json")
local test = require("@std/test")

local buildTools = require("@root/cli/mcp/catalog/buildTools")
local cli = require("@root/cli")
local describeTools = require("@root/cli/mcp/catalog/describeTools")

local need = assert

local DESCRIPTIONS = describeTools(buildTools(cli.describe()))

local function findDescription(name: string): json.Object
	for _, description in DESCRIPTIONS do
		local tool = need(json.asObject(description))

		if tool.name == name then
			return tool
		end
	end

	error(`no tool named {name}`)
end

local function getProperty(tool: json.Object, name: string): json.Object
	local schema = need(json.asObject(need(tool.inputSchema)))
	local properties = need(json.asObject(need(schema.properties)))
	return need(json.asObject(need(properties[name])))
end

test.case("each tool is described with an input schema that refuses other arguments", function(assert)
	for _, description in DESCRIPTIONS do
		local tool = need(json.asObject(description))
		local schema = need(json.asObject(need(tool.inputSchema)))
		assert.eq(schema.additionalProperties, false)
		assert.neq(tool.description, "")
	end

	findDescription("orion_card_add")
	findDescription("orion_node_show")
	findDescription("orion_media_insert")
	findDescription("orion_apply")
end)

test.case("schemas follow each option's value type", function(assert)
	local addCard = findDescription("orion_card_add")
	local schema = need(json.asObject(need(addCard.inputSchema)))
	assert.eq(schema.required, { "label" })
	assert.eq(getProperty(addCard, "label").minLength, 1)
	assert.eq(getProperty(addCard, "status").enum, { "todo", "active", "review", "blocked", "deferred", "done" })
	assert.eq(getProperty(findDescription("orion_card_timeline"), "limit").type, "integer")
	assert.eq(getProperty(addCard, "canvas").pattern, "^[a-z0-9-]+$")

	local setCard = findDescription("orion_card_set")
	assert.eq(getProperty(setCard, "who").enum, { "you", "review", "ci", "" })

	local tidy = findDescription("orion_group_tidy")
	assert.eq(getProperty(tidy, "ifRevision").minimum, 0)
	assert.eq(getProperty(tidy, "ids").type, "array")
	assert.eq(getProperty(tidy, "dryRun").type, "boolean")
	assert.eq(need(json.asObject(need(tidy.inputSchema))).required, nil)

	local addGroup = findDescription("orion_group_add")
	assert.eq(getProperty(addGroup, "items").type, "array")
	assert.eq(need(json.asObject(need(addGroup.inputSchema))).required, { "label", "items" })

	local apply = findDescription("orion_apply")
	assert.eq(need(json.asObject(getProperty(apply, "plan").items)).type, "object")
end)

test.case("note fields ask agents for a plain-language summary with code formatting", function(assert)
	for _, field in { { "orion_note_add", "text" }, { "orion_card_add", "note" }, { "orion_card_set", "note" } } do
		local description = getProperty(findDescription(field[1]), field[2]).description :: string
		assert.strContains(description, "plain-language summary")
		assert.strContains(description, "code formatting")
	end

	assert.strContains(
		getProperty(findDescription("orion_card_set"), "note").description :: string,
		"Replaces the whole note"
	)
end)

test.case("annotations come from each command's declaration", function(assert)
	assert.eq(need(json.asObject(need(findDescription("orion_canvas_check").annotations))).readOnlyHint, true)
	assert.eq(need(json.asObject(need(findDescription("orion_group_remove").annotations))).destructiveHint, true)
	assert.eq(need(json.asObject(need(findDescription("orion_ingest").annotations))).openWorldHint, true)
	assert.eq(findDescription("orion_card_add").annotations, nil)
end)
