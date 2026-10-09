local json = require("@std/json")

local isAbsent = require("@root/cli/mcp/catalog/isAbsent")

local function appendOption(argv: { string }, flag: string, value: json.Value)
	if isAbsent(value) then
		return
	end

	assert(type(value) == "string" or type(value) == "number", `expected {flag} to be a string or number`)
	table.insert(argv, `--{flag}`)
	table.insert(argv, tostring(value))
end

return appendOption
