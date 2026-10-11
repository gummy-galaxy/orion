local cli = require("@batteries/cli")

-- The options batch commands share: targets by id or expression, a dry run, a revision guard, and JSON output.
local batchOptions = {}

function batchOptions.define(parser: cli.Parser, idsHelp: string)
	parser:add("ids", "variadic", { help = idsHelp })
	parser:add("where", "option", { help = "Select targets with an expression instead of ids" })
	parser:add("dry-run", "flag", { help = "Preview changes and current revision without writing" })
	parser:add("if-revision", "option", { help = "Write only if the document has this revision" })
	parser:add("json", "flag", { help = "Print JSON" })
end

function batchOptions.readRevision(parser: cli.Parser): number?
	local value = parser:get("if-revision")
	assert(value == nil or value:match("^%d+$"), "--if-revision must be a nonnegative integer")

	return if value then tonumber(value) else nil
end

return table.freeze(batchOptions)
