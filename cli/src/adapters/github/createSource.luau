local checkOptions = require("@root/adapters/checkOptions")
local getOne = require("@root/adapters/getOne")
local types = require("@root/types")

type Source = types.Source

local NAME = "^[%w_.%-]+$"
local HOST = "^[%w%.%-]+$"

-- GitHub runs no program of its own choosing, so it never has a command.
local function createSource(options: { [string]: { string } }): (Source, { string }?)
	checkOptions("github", options, { host = true, owners = true, include = true, exclude = true })
	local host = assert(getOne(options, "host"), "github needs --host")
	assert(host:match(HOST) and host:find("%.", 1), "invalid GitHub host")
	local owners = options.owners
	assert(owners and #owners > 0, "github needs --owners")

	for _, owner in owners do
		assert(owner:match(NAME), `invalid owner {owner}`)
	end

	for _, key in { "include", "exclude" } do
		for _, repo in options[key] or {} do
			assert(repo:match(NAME), `invalid repository {repo}`)
		end
	end

	local source: Source = {
		id = getOne(options, "id") or `gh-{owners[1]:lower()}`,
		kind = "github",
		host = host,
		owners = owners,
		include = options.include,
		exclude = options.exclude,
	}

	return source, nil
end

return createSource
