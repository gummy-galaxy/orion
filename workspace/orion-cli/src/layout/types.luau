export type Box = {
	x: number,
	y: number,
	width: number,
	height: number,
}

export type Issue = {
	kind: string,
	ids: { string },
	-- Canvas coordinates. Absent for problems with no place on the canvas, such
	-- as a link to a missing item.
	bounds: Box?,
}

return {}
