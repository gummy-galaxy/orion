local json = require("@std/json")

local appendFlag = require("@root/cli/mcp/catalog/appendFlag")
local appendOption = require("@root/cli/mcp/catalog/appendOption")
local getRequiredString = require("@root/cli/mcp/catalog/getRequiredString")
local isAbsent = require("@root/cli/mcp/catalog/isAbsent")
local mcpTypes = require("@root/cli/mcp/types")

type Tool = mcpTypes.Tool

-- Places each field where its command expects it: positionals first, then options and flags.
local function buildArgv(tool: Tool, arguments: json.Object): { string }
	local argv = table.clone(tool.command)

	for _, field in tool.fields do
		if field.at == "positional" then
			table.insert(argv, getRequiredString(arguments, field.name))
		end
	end

	for _, field in tool.fields do
		local value = arguments[field.name]

		if field.at == "option" then
			if isAbsent(value) then
				assert(not field.required, `missing {field.name}`)
			else
				appendOption(argv, field.flag or field.name, value)
			end
		elseif field.at == "flag" then
			appendFlag(argv, field.flag or field.name, value)
		elseif field.at == "csv" then
			local list = if isAbsent(value) then nil else json.asArray(value)
			assert(list and #list > 0, `missing {field.name}`)

			local ids: { string } = {}

			for _, id in list do
				assert(type(id) == "string" and id ~= "", `missing {field.name}`)
				table.insert(ids, id)
			end

			table.insert(argv, `--{field.flag or field.name}`)
			table.insert(argv, table.concat(ids, ","))
		end
	end

	if tool.json then
		table.insert(argv, "--json")
	end

	return argv
end

return buildArgv
