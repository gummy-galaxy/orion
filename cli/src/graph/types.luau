local types = require("@root/types")

-- components counts the components inside, which are parts of a system rather than work.
export type GroupStats = {
	total: number,
	done: number,
	ready: number,
	blocked: number,
	outside: number,
	components: number,
}

export type Derived = {
	status: { [string]: string },
	flow: { [string]: string },
	leverage: { [string]: number },
	upstream: { [string]: number },
	rarity: { [string]: string },
	groups: { [string]: GroupStats },
	-- Progress across every card on the canvas, counted the way each group's is.
	canvas: GroupStats,
	-- Cards snoozed right now, mapped to the UTC time they wake.
	snoozed: { [string]: string },
	-- Open work where it's your move and that isn't blocked or snoozed.
	attention: { [string]: boolean },
	-- Pull request facts for cards where a CI job snooze leaves out a failure, which the app shows over the card's own.
	pulls: { [string]: types.SnoozedFacts },
}

export type ItemFields = {
	label: string?,
	status: string?,
	repo: string?,
	pr: number?,
	who: string?,
	note: string?,
	blurb: string?,
	arrange: string?,
	cover: string?,
	background: string?,
	header: string?,
	kind: string?,
	shape: string?,
	color: string?,
	-- The UTC time a snooze ends, in the form Orion stores; empty to wake it now.
	snoozedUntil: string?,
}

export type Progress = { total: number, done: number, ready: number, components: number }

export type AddOptions = ItemFields & { group: string? }

export type NoteOptions = { group: string?, after: string?, before: string? }

return table.freeze({})
