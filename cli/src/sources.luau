local json = require("@std/json")

local types = require("@root/types")

type Source = types.Source

local sources = {}
local ID = "^[a-z][a-z0-9%-]*$"
local NAME = "^[%w_.%-]+$"
local HOST = "^[%w%.%-]+$"

local function command(value: string): { string }
	local ok, decoded = pcall(json.deserialize, value)
	local array = if ok then json.asArray(decoded :: json.Value) else nil
	assert(array and #array > 0, "--command must be a nonempty JSON array")
	local result = {}
	for _, part in array do
		assert(type(part) == "string" and part ~= "", "--command must contain only nonempty strings")
		local lower = part:lower()
		for _, secret in { "--token", "--password", "--secret", "--api-key", "--auth" } do
			assert(not lower:find(secret, 1, true), "do not store credentials in source commands")
		end
		assert(not lower:match("https?://[^/]*@"), "do not store credentials in source commands")
		table.insert(result, part)
	end
	return result
end

local function parse(args: { string }): ({ [string]: { string } }, string)
	local options: { [string]: { string } } = {}
	local kind = assert(args[1], "source add needs a kind")
	local i = 2
	while i <= #args do
		local key = args[i]:match("^%-%-([%w%-]+)$")
		assert(key, `unexpected argument {args[i]}`)
		local value = assert(args[i + 1], `missing value for --{key}`)
		options[key] = options[key] or {}
		table.insert(options[key], value)
		i += 2
	end
	return options, kind
end

local function one(options: { [string]: { string } }, key: string): string?
	local values = options[key]
	assert(not values or #values == 1, `--{key} may be given once`)
	return if values then values[1] else nil
end

function sources.create(args: { string }): Source
	local options, kind = parse(args)
	local allowed = if kind == "github"
		then { host = true, owner = true, include = true, exclude = true, id = true }
		elseif kind == "jira" then { command = true, browse = true, id = true }
		elseif kind == "hop" then { command = true, id = true }
		else error(`unknown source kind {kind}`)
	for key in options do
		assert(allowed[key], `--{key} does not apply to {kind}`)
	end
	local source: Source = { id = "", kind = kind }
	if kind == "github" then
		local host = assert(one(options, "host"), "github needs --host")
		assert(host:match(HOST) and host:find("%.", 1), "invalid GitHub host")
		local owners = assert(options.owner, "github needs --owner")
		for _, owner in owners do
			assert(owner:match(NAME), `invalid owner {owner}`)
		end
		source.host, source.owners = host, owners
		for _, key in { "include", "exclude" } do
			for _, repo in options[key] or {} do
				assert(repo:match(NAME), `invalid repository {repo}`)
			end
		end
		source.include, source.exclude = options.include, options.exclude
		source.id = one(options, "id") or `gh-{owners[1]:lower()}`
	elseif kind == "jira" then
		local argv = command(assert(one(options, "command"), "jira needs --command"))
		assert(
			argv[1] == "acli" and argv[2] == "jira" and argv[3] == "workitem" and argv[4] == "search",
			"Jira command must be acli jira workitem search"
		)
		source.command = argv
		local browse = one(options, "browse")
		assert(not browse or browse:match("^https://[^/@]+[^@]*$"), "--browse needs an HTTPS URL without credentials")
		source.browse = if browse then browse:gsub("/+$", "") else nil
		source.id = one(options, "id") or "jira"
	else
		local argv: { string } = if one(options, "command") then command(assert(one(options, "command"))) else { "hop" }
		assert((argv[1] == "hop" or argv[1]:match("/hop$")) and #argv == 1, "hop command must name the hop executable")
		source.command = argv
		source.id = one(options, "id") or "hop"
	end
	assert(source.id:match(ID), "source id must use lowercase letters, digits, and hyphens")
	return source
end

function sources.asJson(values: { Source }): json.Array
	local function stringArray(strings: { string }?): json.Array?
		if not strings then
			return nil
		end
		local out: json.Array = {}
		for _, entry in strings do
			table.insert(out, entry)
		end
		return out
	end
	local out: json.Array = {}
	for _, source in values do
		local value = json.object({ id = source.id, kind = source.kind })
		value.host, value.owners, value.include, value.exclude =
			source.host, stringArray(source.owners), stringArray(source.include), stringArray(source.exclude)
		value.command, value.browse = stringArray(source.command), source.browse
		table.insert(out, value)
	end
	return out
end

return table.freeze(sources)
