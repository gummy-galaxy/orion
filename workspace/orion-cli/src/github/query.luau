local json = require("@std/json")
local types = require("@root/types")

type CommandRunner = types.CommandRunner

-- gh can exit non-zero for a partially resolved GraphQL query while retaining
-- usable data. A query that returns no data at all, as one that runs past
-- GitHub's time limit does, raises with GitHub's first error.
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

	local data = json.asObject(body.data)
	local errors = json.asArray(body.errors)
	local first = if errors then json.asObject(errors[1]) else nil

	if data == nil and first and type(first.message) == "string" then
		error(`gh api graphql failed: {first.message}`, 0)
	end

	return data
end

return query
