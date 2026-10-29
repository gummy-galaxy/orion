local fs = require("@std/fs")
local json = require("@std/json")
local test = require("@std/test")

local findCloneAsync = require("@root/adapters/hop/findCloneAsync")
local testing = require("@root/testing")
local types = require("@root/types")

type Source = types.Source

test.case("hop finds a repository's main clone, not its worktrees", function(assert)
	local clone = testing.directory("hop-clone")
	local worktree = testing.directory("hop-clone-worktree")
	fs.createDirectory(clone, { makeParents = true })
	fs.createDirectory(worktree, { makeParents = true })
	local function run()
		return testing.result(
			true,
			json.serialize(json.object({
				worktrees = {
					json.object({
						path = worktree,
						branch = "agent/fix",
						repository = json.object({ remote = "owner/repo" }),
					}),
					json.object({
						path = clone,
						branch = "main",
						primary = true,
						repository = json.object({ remote = "Owner/Repo" }),
					}),
				},
			}))
		)
	end
	local source: Source = { id = "hop", kind = "hop" }

	assert.eq(findCloneAsync(source, run, nil, "owner/repo"), clone)
	assert.eq(findCloneAsync(source, run, nil, "other/repo"), nil)
	fs.removeDirectory(clone, { recursive = true })
	fs.removeDirectory(worktree, { recursive = true })
end)
