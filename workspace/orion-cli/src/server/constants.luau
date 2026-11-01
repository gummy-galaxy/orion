return table.freeze({
	-- How often `orion server start` calls the sync loop's `tickAsync`. Each
	-- tick runs at most one pass, and only when one is due.
	SYNC_TICK_SECONDS = 15,
})
