-- A deep copy of plain data, so a snapshot keeps its values while the document
-- changes in place.
local function copyValue(value: any): any
	if type(value) ~= "table" then
		return value
	end

	local copy = {}

	for key, inner in value do
		copy[key] = copyValue(inner)
	end

	return copy
end

return copyValue
