local json = require("@std/json")

local function createToolResult(text: string, isError: boolean): json.Object
	local result = json.object({ content = { json.object({ type = "text", text = text }) } })

	if isError then
		result.isError = true
	end

	return result
end

return createToolResult
