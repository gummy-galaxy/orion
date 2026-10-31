local geometry = require("@root/geometry")

-- A header is Markdown with layout HTML, kept short enough to read in the band
-- under a group's title.
return function(value: string)
	local characters = utf8.len(value) or #value
	assert(
		characters <= geometry.HEADER_MAX_LENGTH,
		`header must be {geometry.HEADER_MAX_LENGTH} characters or fewer, not {characters}`
	)
end
