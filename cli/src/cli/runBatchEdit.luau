local cli = require("@batteries/cli")

local batchEdit = require("@root/cli/batchEdit")
local context = require("@root/cli/context")
local requestedRevision = require("@root/cli/requestedRevision")

type Context = context.Context

-- Runs a batch edit with the targets and options the command was given.
local function runBatchEdit(parser: cli.Parser, options: Context, action: string)
	local destination = parser:get("to")

	if action == "move" then
		assert(destination or parser:has("top"), "say where with --to <group> or --top")
		assert(not (destination and parser:has("top")), "use --to or --top, not both")
	end

	batchEdit({
		dir = options.dir,
		action = action,
		ids = parser:variadics(),
		where = parser:get("where"),
		dryRun = parser:has("dry-run"),
		asJson = parser:has("json"),
		ifRevision = requestedRevision(parser),
		destination = if parser:has("top") then nil else destination,
		reconnect = parser:has("reconnect"),
		write = options.write,
	})
end

return runBatchEdit
