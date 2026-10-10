local json = require("@std/json")
local test = require("@std/test")

local graph = require("@root/graph")
local matchesExpression = require("@root/query/matchesExpression")
local parseExpression = require("@root/query/parseExpression")
local testing = require("@root/testing")

test.case("matches derived status and source references", function(assert)
	local item = testing.task("pr-card", "Fix Query", "todo", "scope", {
		repo = "vocksel/orion",
		refs = {
			json.object({
				source = "github",
				kind = "pull",
				key = "vocksel/orion#86",
				details = json.object({ draft = true }),
			}),
			json.object({ source = "jira", kind = "issue", key = "ORION-86" }),
		},
	})
	local doc = testing.createDoc({ testing.group("scope", "Scope"), item })
	local derived = graph.derive(doc)
	for _, expression in
		{
			[[kind = "step"]],
			[[repo = "vocksel/orion"]],
			[[status = "ready" and recordedStatus = "todo"]],
			[[group = "scope"]],
			[[draft = "true"]],
			[[label ~ "QUERY"]],
			[[pr = "86"]],
			[[ref = "ORION-86"]],
			[[ref ~ "ORION"]],
			[[ref != "OTHER-1"]],
		}
	do
		assert.eq(matchesExpression(derived, item, parseExpression(expression)), true)
	end
	assert.eq(matchesExpression(derived, doc.nodes[1], parseExpression([[kind = "group"]])), true)
end)

test.case("missing fields stay unmatched under inequality and not", function(assert)
	local item = testing.task("plain", "Plain", "todo")
	local doc = testing.createDoc({ item })
	local derived = graph.derive(doc)
	for _, expression in
		{
			[[repo != "orion"]],
			[[not repo = "orion"]],
			[[draft != "true"]],
			[[pr != "86"]],
		}
	do
		assert.eq(matchesExpression(derived, item, parseExpression(expression)), false)
	end
	assert.eq(matchesExpression(derived, item, parseExpression([[repo != "orion" or label = "Plain"]])), true)
end)
