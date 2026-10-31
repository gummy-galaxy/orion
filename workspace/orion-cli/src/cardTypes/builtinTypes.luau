local cardTypes = require("@root/cardTypes/types")

type CardType = cardTypes.CardType
type Field = cardTypes.Field
type Meaning = cardTypes.Meaning
type State = cardTypes.State

-- The states a person records on work, in the order the app lists them.
-- Blocked here is set by hand, for a blocker outside the graph.
local WORK_STATES: { State } = {
	{ name = "todo", label = "To do", means = "todo" },
	{ name = "active", label = "In progress", means = "active" },
	{ name = "review", label = "In review", means = "review" },
	{ name = "blocked", label = "Blocked", means = "blocked" },
	{ name = "deferred", label = "Deferred", means = "deferred" },
	{ name = "done", label = "Done", means = "done" },
}

local WHO: Field = {
	name = "who",
	label = "Whose move",
	kind = "choice",
	choices = {
		{ value = "you", label = "You" },
		{ value = "review", label = "Reviewer" },
		{ value = "ci", label = "CI" },
	},
}

local REPO: Field = { name = "repo", label = "Repository", kind = "text" }

local WORK: Meaning = { isWork = true, canBlock = true, canBeDone = true, doneWhen = "state" }

-- The types Orion ships. Every card the app and CLI know how to make carries
-- one of these, so none of them is a special case.
local builtinTypes: { CardType } = {
	{
		name = "step",
		label = "Step",
		pack = "orion",
		fields = { WHO },
		face = { layout = "card", shows = {} },
		states = WORK_STATES,
		meaning = WORK,
	},
	{
		name = "pr",
		label = "Pull request",
		pack = "orion",
		fields = { REPO, WHO },
		face = { layout = "card", shows = {} },
		states = WORK_STATES,
		meaning = WORK,
	},
	{
		-- A pull request that's expected but not opened yet.
		name = "placeholder",
		label = "Expected pull request",
		pack = "orion",
		fields = { REPO, WHO },
		face = { layout = "card", shows = {} },
		states = WORK_STATES,
		meaning = WORK,
	},
	{
		-- A milestone or sign-off, done once everything it waits on is.
		name = "gate",
		label = "Gate",
		pack = "orion",
		fields = { WHO },
		face = { layout = "card", shows = {} },
		states = WORK_STATES,
		meaning = { isWork = true, canBlock = true, canBeDone = true, doneWhen = "inputs" },
	},
	{
		-- Notes aren't work. They pass on whatever blocks them.
		name = "note",
		label = "Note",
		pack = "orion",
		fields = {},
		face = { layout = "note", shows = {} },
		states = {},
		meaning = { isWork = false, canBlock = false, canBeDone = true, doneWhen = "inputs" },
	},
	{
		-- A part of a system diagram, like a service or a data store.
		name = "component",
		label = "Component",
		pack = "orion",
		fields = {
			{
				name = "shape",
				label = "Shape",
				kind = "choice",
				choices = {
					{ value = "service", label = "Service" },
					{ value = "store", label = "Store" },
					{ value = "actor", label = "Actor" },
					{ value = "external", label = "External" },
					{ value = "interface", label = "Interface" },
					{ value = "process", label = "Process" },
					{ value = "queue", label = "Queue" },
				},
				default = "service",
			},
			{
				name = "color",
				label = "Tint",
				kind = "choice",
				choices = {
					{ value = "teal", label = "Teal" },
					{ value = "blue", label = "Blue" },
					{ value = "purple", label = "Purple" },
					{ value = "amber", label = "Amber" },
					{ value = "rose", label = "Rose" },
					{ value = "green", label = "Green" },
					{ value = "slate", label = "Slate" },
				},
			},
		},
		face = { layout = "component", shows = {} },
		states = {},
		meaning = { isWork = false, canBlock = false, canBeDone = false, doneWhen = "state" },
	},
	{
		name = "image",
		label = "Image",
		pack = "orion",
		fields = {},
		face = { layout = "image", shows = {} },
		states = {},
		meaning = { isWork = false, canBlock = false, canBeDone = false, doneWhen = "state" },
	},
}

return builtinTypes
