local test = require("@std/test")

local checkFields = require("@root/graph/checkFields")
local fieldValues = require("@root/fieldValues")
local graphTypes = require("@root/graph/types")

test.case("checkFields accepts known values and empty values that clear a field", function(assert)
	local accepted: { graphTypes.ItemFields } = {
		{},
		{ repo = "vocksel/orion", pr = 12, status = "review", who = "you", kind = "gate" },
		{ repo = "", who = "", shape = "", color = "", cover = "", background = "", header = "" },
		{ shape = "store", color = "amber", arrange = "custom", snoozedUntil = "2026-10-12T17:00:00Z" },
	}

	for _, fields in accepted do
		assert.eq(pcall(checkFields, fields), true)
	end
end)

test.case("checkFields refuses values Orion doesn't store", function(assert)
	local cases: { { any } } = {
		{ { repo = "orion" }, "repo must be owner/name" },
		{ { repo = "", pr = 1 }, "pr needs a repository as owner/name" },
		{ { pr = 1.5 }, "pr must be a positive whole number" },
		{ { status = "maybe" }, `status must be one of {table.concat(fieldValues.statuses, ", ")}` },
		{ { who = "them" }, `who must be one of {table.concat(fieldValues.who, ", ")}` },
		{ { kind = "milestone" }, `kind must be one of {table.concat(fieldValues.kinds, ", ")}` },
		{ { arrange = "grid" }, `arrange must be one of {table.concat(fieldValues.arrangements, ", ")}` },
		{ { shape = "blob" }, `shape must be one of {table.concat(fieldValues.shapes, ", ")}` },
		{ { color = "mauve" }, `color must be one of {table.concat(fieldValues.colors, ", ")}` },
		{ { cover = "../orion.json" }, "cover must be an image asset id, such as the asset from orion media insert" },
		{ { snoozedUntil = "next week" }, "snoozedUntil must be a UTC time such as 2026-10-12T17:00:00Z" },
	}

	for _, case in cases do
		assert.throwsWith(case[2], function()
			checkFields(case[1])
		end)
	end

	assert.throws(function()
		checkFields({ background = "red" })
	end)
end)
