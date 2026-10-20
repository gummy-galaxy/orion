local cli = require("@batteries/cli")

local addArgument = require("@root/cli/addArgument")

-- Targets given as ids or a --where expression, with a dry run and a revision guard.
local function addBatchOptions(parser: cli.Parser, help: string)
	parser:add("ids", "variadic", { help = help })
	parser:add("where", "option", { help = "Select targets with an expression instead of ids" })
	parser:add("dry-run", "flag", { help = "Preview changes and current revision without writing" })
	addArgument(parser, "if-revision", "option", {
		help = "Write only if the document has this revision",
		type = "integer",
		minimum = 0,
	})
	parser:add("json", "flag", { help = "Print JSON" })
end

return addBatchOptions
