local json = require("@std/json")

local context = require("@root/cli/context")

type Context = context.Context

-- Reports a command's result as JSON under --json, or as its line of text.
local function writeResult(options: Context, value: json.Object, text: string)
	options.write(if options.asJson then json.serialize(value, true) else text)
end

return writeResult
