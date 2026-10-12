-- Turns a workspace label into a name: lowercase words joined by hyphens, such as "Focus areas" to "focus-areas".
local function deriveWorkspaceName(label: string): string
	local name = label:lower():gsub("[^%w]+", "-"):gsub("^%-+", ""):gsub("%-+$", "")
	assert(name ~= "", "pass a name: the label has no letters or digits to derive one from")
	return name
end

return deriveWorkspaceName
