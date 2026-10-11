local cli = require("@batteries/cli")

local function requestedRevision(parser: cli.Parser): number?
	local value = parser:get("if-revision")
	assert(value == nil or value:match("^%d+$"), "--if-revision must be a nonnegative integer")
	return if value then tonumber(value) else nil
end

return requestedRevision
