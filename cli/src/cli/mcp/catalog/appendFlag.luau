local json = require("@std/json")

local function appendFlag(argv: { string }, flag: string, value: json.Value)
	if value == true then
		table.insert(argv, `--{flag}`)
	end
end

return appendFlag
