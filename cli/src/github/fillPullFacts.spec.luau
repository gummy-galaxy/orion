local json = require("@std/json")
local test = require("@std/test")

local fillPullFacts = require("@root/github/fillPullFacts")
local findRef = require("@root/refs/findRef")
local testing = require("@root/testing")

test.case("fillPullFacts gives a pull request recorded without facts the ones its details support", function(assert)
	local item = testing.task("a", "A", "done")
	local refs: json.Array = {
		json.object({
			source = "github",
			kind = "pull",
			key = "vocksel/orion#1",
			details = json.object({ state = "MERGED", draft = false, checkedAt = "then" }),
		}),
	}
	item.data.refs = refs

	fillPullFacts(item)
	local ref = findRef(item, "pull")

	assert.eq(ref and ref.stateLabel, "Merged on GitHub")
	assert.eq(ref and ref.checkedAt, "then")
end)

test.case("fillPullFacts leaves refs that already carry facts alone", function(assert)
	local item = testing.task("a", "A", "todo")
	local refs: json.Array = {
		json.object({
			source = "github",
			kind = "pull",
			key = "vocksel/orion#1",
			checkedAt = "now",
			stateLabel = "Approved on GitHub",
			details = json.object({ state = "MERGED", draft = false, checkedAt = "then" }),
		}),
	}
	item.data.refs = refs

	fillPullFacts(item)
	local ref = findRef(item, "pull")

	assert.eq(ref and ref.stateLabel, "Approved on GitHub")
end)
