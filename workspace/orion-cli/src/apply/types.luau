-- One step of a plan. `op` names the step, and the other fields are what that
-- step reads; each step checks its own. The edit steps (setFields, link,
-- unlink, insert, group, ungroup, move, remove, removeGroup, tidy) use the
-- names and fields of the operations in #93, so a plan can move onto that
-- model. addCard, addNote, and handles are new here.
export type Operation = {
	op: string,
	-- Names a card, note, or group that this step creates, so later steps can
	-- refer to it as "@handle".
	handle: string?,
	id: string?,
	from: string?,
	to: string?,
	-- The link kind for link: blocks or related.
	kind: string?,
	-- The group a card or note goes into, or the destination of move. Nil means
	-- the top level.
	group: string?,
	items: { string }?,
	label: string?,
	text: string?,
	after: string?,
	before: string?,
	ref: string?,
	reconnect: boolean?,
	-- Card fields for addCard, or the field changes for setFields.
	fields: { [string]: string | number }?,
}

return nil
