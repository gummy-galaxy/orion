--[[
	The grammar `--where` and `--sort` take, as data. parseExpression reads its
	fields and operators from here, `orion help node query` lists them, and
	`lute run docs` writes the reference page from it, so all three describe
	what the parser accepts. Every example has to parse; the spec checks.
]]

local fieldValues = require("@root/fieldValues")

export type Field = {
	name: string,
	help: string,
	-- Whether `~` works on the field, matching text inside it.
	isText: boolean?,
	-- The only values the field takes, when there's a fixed set.
	values: { string }?,
	example: string,
}

export type Operator = {
	symbol: string,
	help: string,
}

local FIELDS: { Field } = {
	{
		name = "kind",
		help = "What the node is: `pr` for a card with a pull request, `placeholder` for one with only a repository, `step`, `gate`, `component`, `note`, `group`, or `image`.",
		example = [[kind = "gate"]],
	},
	{
		name = "repo",
		help = "The repository a card belongs to, as `owner/name`.",
		example = [[repo = "gummy-galaxy/orion"]],
	},
	{
		name = "status",
		help = "The derived status the CLI lists, such as `ready` for a card with nothing open in its way.",
		example = [[status = "ready"]],
	},
	{
		name = "recordedStatus",
		help = "The status stored on the card, before the graph derives `ready` or `blocked` from it.",
		example = [[recordedStatus = "todo"]],
	},
	{
		name = "group",
		help = "The group that directly holds the node, named by its id, its label, or its path of labels from the top level separated by `/`, ignoring case. With `~` it matches text in that path.",
		isText = true,
		example = [[group = "Release / Docs"]],
	},
	{
		name = "who",
		help = "Whose move a card is: yours, a reviewer's, or CI's.",
		values = fieldValues.who,
		example = [[who = "you"]],
	},
	{
		name = "priority",
		help = "The priority a card's source gives it, such as `High` from Jira.",
		isText = true,
		example = [[priority = "High"]],
	},
	{
		name = "draft",
		help = "Whether the card's pull request is a draft.",
		values = { "true", "false" },
		example = [[draft = "true"]],
	},
	{
		name = "label",
		help = "The card's or group's label.",
		isText = true,
		example = [[label ~ "slider"]],
	},
	{
		name = "note",
		help = "The text of a card's note.",
		isText = true,
		example = [[note ~ "checklist"]],
	},
	{
		name = "pr",
		help = "The number of the card's pull request, without the `#`.",
		example = [[pr = "86"]],
	},
	{
		name = "ref",
		help = "The key of any ref on the card, such as `owner/name#12` or `ABC-12`. With `=` and `!=` it matches whole keys, ignoring case.",
		isText = true,
		example = [[ref = "gummy-galaxy/orion#86"]],
	},
	{
		name = "snoozed",
		help = "Whether a card is snoozed right now. Groups have no value.",
		values = { "true", "false" },
		example = [[snoozed = "false"]],
	},
}

local OPERATORS: { Operator } = {
	{ symbol = "=", help = "The field equals the value." },
	{ symbol = "!=", help = "The field has a value, and it isn't this one." },
	{ symbol = "~", help = "The field contains the value, ignoring case. Only text fields take it." },
}

-- How comparisons combine, tightest first.
local COMBINATORS: { Operator } = {
	{ symbol = "( … )", help = "Groups an expression." },
	{ symbol = "not", help = "Matches what the expression doesn't. A node missing the field still doesn't match." },
	{ symbol = "and", help = "Matches what both sides match." },
	{ symbol = "or", help = "Matches what either side matches." },
}

local EXAMPLES: { string } = {
	[[repo = "gummy-galaxy/orion" and status = "ready"]],
	[[kind = "group" and label ~ "release"]],
	[[pr = "86" or ref = "ABC-12"]],
	[[not (draft = "true") and status != "done"]],
	[[group ~ "release" and who = "you"]],
}

-- What `--sort` takes: fields separated by commas, each descending when it
-- starts with `-`.
local SORT_EXAMPLES: { string } = {
	"label",
	"status,-pr",
}

local fieldsByName: { [string]: Field } = {}

for _, field in FIELDS do
	fieldsByName[field.name] = field
end

local function getFieldNames(): { string }
	local names: { string } = {}

	for _, field in FIELDS do
		table.insert(names, field.name)
	end

	return names
end

local function getTextFieldNames(): { string }
	local names: { string } = {}

	for _, field in FIELDS do
		if field.isText then
			table.insert(names, field.name)
		end
	end

	return names
end

return table.freeze({
	fields = table.freeze(FIELDS),
	fieldsByName = table.freeze(fieldsByName),
	fieldNames = table.freeze(getFieldNames()),
	textFieldNames = table.freeze(getTextFieldNames()),
	operators = table.freeze(OPERATORS),
	combinators = table.freeze(COMBINATORS),
	examples = table.freeze(EXAMPLES),
	sortExamples = table.freeze(SORT_EXAMPLES),
})
