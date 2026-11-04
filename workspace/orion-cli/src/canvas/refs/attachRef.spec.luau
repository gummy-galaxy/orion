local json = require("@std/json")
local test = require("@std/test")

local attachRef = require("@root/canvas/refs/attachRef")
local findRef = require("@root/canvas/refs/findRef")
local getRefs = require("@root/canvas/refs/getRefs")
local resolveRef = require("@root/sources/resolveRef")
local testing = require("@root/testing")

test.case("attachRef adds a ref, fills in a missing repository, and refreshes the kind", function(assert)
	local doc = testing.createDoc({ testing.task("a", "A", "todo") })
	local item = attachRef(doc, "a", {
		ref = { source = "github", kind = "pull", key = "vocksel/orion#12" },
		repo = "vocksel/orion",
	})
	assert.eq((findRef(item, "pull") :: any).key, "vocksel/orion#12")
	assert.eq(item.data.repo, "vocksel/orion")
	assert.eq(testing.primaryType(item), "pr")

	attachRef(doc, "a", { ref = { source = "github", kind = "issue", key = "flipbook-labs/flipbook#1" }, repo = "x/y" })
	assert.eq(item.data.repo, "vocksel/orion")
end)

test.case("attachRef refuses groups", function(assert)
	local doc = testing.createDoc({ testing.group("g", "Group") })
	assert.throwsWith("groups don't take refs; attach it to an item", function()
		attachRef(doc, "g", { ref = { source = "jira", kind = "issue", key = "ORN-1" } })
	end)
end)

test.case("a ref named by its repository's old name merges into the one the card has", function(assert)
	local doc = testing.createDoc({
		testing.task("moved", "Moved", "active", nil, {
			refs = {
				json.object({
					source = "github",
					kind = "pull",
					key = "gummy-galaxy/orion#12",
					id = "1#12",
					status = "open",
				}),
			},
		}),
		testing.task("fresh", "Fresh", "todo"),
	})
	doc.repositories = json.object({
		["1"] = json.object({ name = "gummy-galaxy/orion", aliases = { "vocksel/orion" } }),
	})

	attachRef(doc, "moved", resolveRef("https://github.com/vocksel/orion/pull/12", {}))
	attachRef(doc, "fresh", resolveRef("branch:vocksel/orion@agent/fix", {}))

	local refs = getRefs(doc.nodes[1])
	assert.eq(#refs, 1)
	assert.eq(refs[1].key, "gummy-galaxy/orion#12")
	assert.eq(refs[1].status, "open")

	local branch = getRefs(doc.nodes[2])[1]
	assert.eq(branch.key, "gummy-galaxy/orion@agent/fix")
	assert.eq(branch.id, "1@agent/fix")
	assert.eq(doc.nodes[2].data.repo, "gummy-galaxy/orion")
end)
