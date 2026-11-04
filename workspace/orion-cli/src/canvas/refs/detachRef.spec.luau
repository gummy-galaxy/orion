local test = require("@std/test")

local detachRef = require("@root/canvas/refs/detachRef")
local findRef = require("@root/canvas/refs/findRef")
local testing = require("@root/testing")

local function pullCard()
	return testing.task("a", "A", "todo", nil, {
		repo = "vocksel/orion",
		refs = {
			{ source = "github", kind = "pull", key = "vocksel/orion#12" },
			{ source = "github", kind = "issue", key = "vocksel/orion#12" },
		},
	})
end

test.case("detachRef removes a ref by key without case and refreshes the kind", function(assert)
	local doc = testing.createDoc({ pullCard() })
	local item = detachRef(doc, "a", "Vocksel/Orion#12")
	assert.eq(findRef(item, "pull"), nil)
	assert.eq(findRef(item, "issue"), nil)
	assert.eq(testing.primaryType(item), "placeholder")
end)

test.case("detachRef narrows to a kind when one is given", function(assert)
	local doc = testing.createDoc({ pullCard() })
	local item = detachRef(doc, "a", "vocksel/orion#12", "issue")
	assert.eq(findRef(item, "issue"), nil)
	assert.eq((findRef(item, "pull") :: any).key, "vocksel/orion#12")
end)

test.case("detachRef refuses groups and a key the item doesn't have", function(assert)
	local doc = testing.createDoc({ testing.group("g", "Group"), pullCard() })
	assert.throwsWith("groups don't take refs", function()
		detachRef(doc, "g", "vocksel/orion#12")
	end)
	assert.throwsWith('"a" has no ref ORN-1', function()
		detachRef(doc, "a", "ORN-1")
	end)
end)
