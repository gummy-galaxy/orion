local json = require("@std/json")

-- How a field's value is entered and shown.
export type FieldKind = "text" | "markdown" | "number" | "choice" | "date" | "url" | "boolean"

export type Choice = { value: string, label: string }

-- One value a type adds to the cards that carry it. `choices` lists the values
-- a choice field takes, and `default` is the value a card shows before anyone
-- sets one.
export type Field = {
	name: string,
	label: string,
	kind: FieldKind,
	choices: { Choice }?,
	default: json.Value?,
}

-- What a state counts as when Orion works out what's done, what's waiting,
-- and what's stuck.
export type StateMeaning = "todo" | "active" | "review" | "blocked" | "deferred" | "done"

-- One state a card of the type can be in, such as Approved for a design, and
-- what it counts as.
export type State = { name: string, label: string, means: StateMeaning }

-- How a card of the type is drawn. `layout` picks one of the app's faces,
-- `size` sets its size before a skin or its text adjusts it, and `shows` lists
-- the fields on its face, in order.
export type Face = {
	layout: "card" | "note" | "component" | "image",
	size: { width: number, height: number }?,
	shows: { string },
}

-- How cards of the type feed what Orion derives. `isWork` counts them toward
-- progress, rarity, and whose move it is. `canBlock` lets an open one hold up
-- the cards it links to; otherwise it only passes on what reaches it.
-- `canBeDone` gives them a status at all, and `doneWhen` says whether their
-- state or the cards they wait on decide when they're done.
export type Meaning = {
	isWork: boolean,
	canBlock: boolean,
	canBeDone: boolean,
	doneWhen: "state" | "inputs",
}

-- A type a card can carry. A pack is where it was declared: `orion` for the
-- types Orion ships, or the source kind that registered it. `supersedes` names
-- the types this one takes the face from when a card carries both, such as a
-- pull request replacing the placeholder that expected it.
export type CardType = {
	name: string,
	label: string,
	pack: string,
	supersedes: { string }?,
	fields: { Field },
	face: Face,
	states: { State },
	meaning: Meaning,
}

-- Every registered type, by name and in the order packs declared them.
export type Registry = { byName: { [string]: CardType }, ordered: { CardType } }

-- The types attached to a card. The primary type picks its face, and the rest
-- add fields and badges. `types` lists them all, primary first.
export type ItemTypes = { primary: string, types: { string } }

return table.freeze({})
