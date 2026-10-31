local json = require("@std/json")
local test = require("@std/test")

local createScope = require("@root/query/createScope")
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
	local scope = createScope(doc)
	for _, expression in
		{
			[[kind = "pr"]],
			[[type = "step"]],
			[[type != "gate"]],
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
		assert.eq(matchesExpression(scope, item, parseExpression(expression)), true)
	end
	assert.eq(matchesExpression(scope, doc.nodes[1], parseExpression([[kind = "group"]])), true)
end)

test.case("note matches the card's note text, and a missing note never matches", function(assert)
	local item = testing.task("noted", "Noted", "todo", nil, { note = "Confirm the release date" })
	local bare = testing.task("bare", "Bare", "todo")
	local doc = testing.createDoc({ item, bare })
	local scope = createScope(doc)
	assert.eq(matchesExpression(scope, item, parseExpression([[note ~ "RELEASE"]])), true)
	assert.eq(matchesExpression(scope, item, parseExpression([[note = "Confirm the release date"]])), true)
	assert.eq(matchesExpression(scope, bare, parseExpression([[note ~ "release"]])), false)
	assert.eq(matchesExpression(scope, bare, parseExpression([[note != "release"]])), false)
end)

test.case("missing fields stay unmatched under inequality and not", function(assert)
	local item = testing.task("plain", "Plain", "todo")
	local doc = testing.createDoc({ item })
	local scope = createScope(doc)
	for _, expression in
		{
			[[repo != "orion"]],
			[[not repo = "orion"]],
			[[draft != "true"]],
			[[pr != "86"]],
		}
	do
		assert.eq(matchesExpression(scope, item, parseExpression(expression)), false)
	end
	assert.eq(matchesExpression(scope, item, parseExpression([[repo != "orion" or label = "Plain"]])), true)
end)

test.case("group matches by id, label, or path, ignoring case", function(assert)
	local item = testing.task("card", "Card", "todo", "docs")
	local loose = testing.task("loose", "Loose", "todo")
	local doc = testing.createDoc({
		testing.group("release", "Release"),
		testing.group("docs", "Docs", "release"),
		item,
		loose,
	})
	local scope = createScope(doc)

	for _, expression in
		{
			[[group = "docs"]],
			[[group = "DOCS"]],
			[[group = "Release/Docs"]],
			[[group = " release / docs "]],
			[[group ~ "lease / do"]],
			[[group != "Release"]],
			[[group != "Docs / Release"]],
		}
	do
		assert.eq(matchesExpression(scope, item, parseExpression(expression)), true)
	end

	for _, expression in { [[group = "Release"]], [[group = "Other/Docs"]], [[group = "Release/Docs/More"]] } do
		assert.eq(matchesExpression(scope, item, parseExpression(expression)), false)
	end

	assert.eq(matchesExpression(scope, doc.nodes[2], parseExpression([[group = "Release"]])), true)
	assert.eq(matchesExpression(scope, loose, parseExpression([[group != "Release"]])), false)
	assert.eq(matchesExpression(scope, loose, parseExpression([[group ~ "e"]])), false)
end)

test.case("who and a source's priority match, and cards without them never do", function(assert)
	local item = testing.task("jira-card", "Jira card", "todo", nil, {
		who = "you",
		refs = {
			json.object({ source = "github", kind = "pull", key = "gummy-galaxy/orion#1" }),
			json.object({
				source = "jira",
				kind = "issue",
				key = "ABC-1",
				details = json.object({ priority = "High" }),
			}),
		},
	})
	local bare = testing.task("bare", "Bare", "todo")
	local scope = createScope(testing.createDoc({ item, bare }))

	for _, expression in { [[who = "you"]], [[priority = "High"]], [[priority ~ "high"]], [[priority != "Low"]] } do
		assert.eq(matchesExpression(scope, item, parseExpression(expression)), true)
		assert.eq(matchesExpression(scope, bare, parseExpression(expression)), false)
	end

	assert.throwsWith("query at column 11: who must be 'you', 'review', or 'ci'", function()
		parseExpression([[who = "me"]])
	end)
end)
