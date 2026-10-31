local json = require("@std/json")
local test = require("@std/test")

local resolveId = require("@root/canvas/query/resolveId")
local selectors = require("@root/canvas/query/selectors")
local testing = require("@root/testing")

test.case("every documented selector example resolves to its card", function(assert)
	local doc = testing.createDoc({
		testing.task("slider", "Extract slider", "active", nil, {
			refs = {
				json.object({ source = "github", kind = "pull", key = "gummy-galaxy/orion#86" }),
				json.object({ source = "jira", kind = "issue", key = "ABC-12" }),
			},
		}),
	})
	doc.settings.sources = { { id = "jira", kind = "jira", browse = "https://jira.example.com/browse" } }

	for _, selector in selectors.list do
		for _, example in selector.examples do
			assert.eq(resolveId(doc, example), "slider")
		end
	end
end)

test.case("an unknown selector names the known ones", function(assert)
	assert.throwsWith(
		'"owner:orion" uses an unknown selector; use label:<text>, ref:<key or ref>, pr:<number>',
		function()
			resolveId(testing.createDoc({}), "owner:orion")
		end
	)
end)
