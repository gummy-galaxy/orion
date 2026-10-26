-- The value as a table whose fields can be read, or nil when it isn't a table,
-- such as an error that might be a string or a table.
local function asObject(value: unknown): { [string]: unknown }?
	return if type(value) == "table" then value :: { [string]: unknown } else nil
end

return asObject
