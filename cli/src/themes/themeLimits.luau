-- A theme file is a short list of token values, so a larger file is refused before it is read.
return table.freeze({
	maxBytes = 256 * 1024,
})
