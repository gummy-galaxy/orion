local json = require("@std/json")

local types = require("@root/types")

type CommandRunner = types.CommandRunner

local function getCommandJson(run: CommandRunner, argv: { string }): json.Value
	local result = run(argv)
	assert(result.ok, `{argv[1]} failed: {result.stderr}`)
	local succeeded, value = pcall(json.deserialize, result.stdout)
	assert(succeeded, `{argv[1]} returned invalid JSON`)
	return value :: json.Value
end

return getCommandJson
