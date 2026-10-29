local fs = require("@std/fs")
local json = require("@std/json")
local test = require("@std/test")

local findCheckoutAsync = require("@root/adapters/hop/findCheckoutAsync")
local testing = require("@root/testing")
local types = require("@root/types")

type Source = types.Source

local SOURCE: Source = { id = "hop", kind = "hop" }

local function listing(folder: string): string
	return json.serialize(json.object({
		worktrees = {
			json.object({
				path = "/elsewhere",
				branch = "agent/fix",
				repository = json.object({ remote = "other/repo" }),
			}),
			json.object({ path = folder, branch = "agent/fix", repository = json.object({ remote = "Owner/Repo" }) }),
		},
	}))
end

test.case("hop finds the worktree for a repository's branch", function(assert)
	local folder = testing.directory("hop-checkout")
	fs.createDirectory(folder, { makeParents = true })
	local calls: { { string } } = {}
	local function run(argv: { string })
		table.insert(calls, argv)
		return testing.result(true, listing(folder))
	end

	assert.eq(findCheckoutAsync(SOURCE, run, nil, "owner/repo", "agent/fix"), folder)
	assert.eq(calls[1], { "hop", "list", "--json" })
	assert.eq(findCheckoutAsync(SOURCE, run, nil, "owner/repo", "agent/other"), nil)
	assert.eq(findCheckoutAsync(SOURCE, run, { "/opt/hop" }, "owner/repo", "agent/fix"), folder)
	assert.eq(calls[3][1], "/opt/hop")
	fs.removeDirectory(folder, { recursive = true })
end)

test.case("a missing folder or a failing hop finds nothing", function(assert)
	local function listMissing()
		return testing.result(true, listing("/no/such/folder"))
	end
	local function fail()
		return testing.result(false, "", "hop: not found")
	end

	assert.eq(findCheckoutAsync(SOURCE, listMissing, nil, "owner/repo", "agent/fix"), nil)
	assert.eq(findCheckoutAsync(SOURCE, fail, nil, "owner/repo", "agent/fix"), nil)
end)
