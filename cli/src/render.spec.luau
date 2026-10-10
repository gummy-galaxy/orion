local test = require("@std/test")

local graph = require("@root/graph")
local render = require("@root/render")
local testing = require("@root/testing")

test.case("render uses the primary ref and emits the source-neutral fields", function(assert)
	local item = testing.task("a", "A", "todo", nil, {
		repo = "vocksel/orion",
		refs = {
			{ source = "hop", kind = "branch", key = "vocksel/orion@main" },
			{ source = "jira", kind = "issue", key = "ORN-1", url = "https://jira.example/ORN-1" },
		},
	})
	local doc = testing.createDoc({ item })
	assert.eq(render.tag(item), "ORN-1")
	local rendered = render.itemJson(doc, graph.derive(doc), item)
	assert.eq(rendered.repo, "vocksel/orion")
	assert.eq(rendered.refs ~= nil, true)
	assert.eq(rendered.pr, nil)
	assert.eq(rendered.github, nil)
end)
