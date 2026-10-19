-- An enum's values with "", for options where an empty value clears the field.
local function appendEmptyValue(values: { string }): { string }
	local clearable = table.clone(values)
	table.insert(clearable, "")
	return clearable
end

return appendEmptyValue
