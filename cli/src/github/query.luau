local json = require("@std/json")
local types = require("@root/types")

type CommandRunner = types.CommandRunner

-- gh can exit non-zero for a partially resolved GraphQL query while retaining usable data.
local function query(run: CommandRunner, source: string, host: string?): json.Object?
	local argv = { "gh", "api" }

	if host then
		table.insert(argv, "--hostname")
		table.insert(argv, host)
	end

	table.insert(argv, "graphql")
	table.insert(argv, "-f")
	table.insert(argv, `query={source}`)
	local succeeded, response = pcall(run, argv, nil)

	if not succeeded then
		return nil
	end

	local decodedOk, decoded = pcall(json.deserialize, response.stdout)
	local body = if decodedOk then json.asObject(decoded :: json.Value) else nil

	if body == nil then
		assert(response.ok, `gh api graphql failed: {response.stderr}`)
		return nil
	end

	return json.asObject(body.data)
end

return query
