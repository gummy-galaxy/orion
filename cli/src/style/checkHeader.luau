local HEADER_MAX_CHARACTERS = 2000

-- A header is Markdown with layout HTML, kept short enough to read in the band under a group's title.
return function(value: string)
	local characters = utf8.len(value) or #value
	assert(
		characters <= HEADER_MAX_CHARACTERS,
		`header must be {HEADER_MAX_CHARACTERS} characters or fewer, not {characters}`
	)
end
