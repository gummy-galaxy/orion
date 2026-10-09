local function getStringField(value: unknown): string?
	return if type(value) == "string" then value else nil
end

return getStringField
