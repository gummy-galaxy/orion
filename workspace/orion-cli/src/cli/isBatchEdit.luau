local cli = require("@batteries/cli")

-- Whether an edit command goes through batchEdit: more than one target, a --where expression, or any of the batch
-- options. A single plain id takes the shorter path and prints one line.
local function isBatchEdit(parser: cli.Parser): boolean
	return #parser:variadics() ~= 1
		or parser:get("where") ~= nil
		or parser:has("dry-run")
		or parser:has("json")
		or parser:get("if-revision") ~= nil
		or parser:has("reconnect")
end

return isBatchEdit
