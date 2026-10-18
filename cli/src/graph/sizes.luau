-- Card and group sizes match the app so CLI placements line up with its layout.
return table.freeze({
	TASK_WIDTH = 216,
	TASK_HEIGHT = 72,
	GROUP_PADDING = 32,
	GROUP_HEADER_HEIGHT = 78,
	-- The band a group's header takes under its title row. The app reserves the same band.
	GROUP_HEADER_BAND = 112,
	ITEM_GAP = 48,
})
