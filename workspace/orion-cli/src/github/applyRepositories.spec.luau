local json = require("@std/json")
local test = require("@std/test")

local applyRepositories = require("@root/github/applyRepositories")
local getRefs = require("@root/refs/getRefs")
local testing = require("@root/testing")

local function card(id: string, refs: { json.Object }): any
	return testing.task(id, id, "active", nil, json.object({ refs = refs }))
end

test.case("refs with no id take their repository's id, and the directory records its name", function(assert)
	local doc = testing.createDoc({
		card("a", {
			json.object({ source = "github", kind = "pull", key = "vocksel/orion#12" }),
			json.object({ source = "hop", kind = "branch", key = "Vocksel/Orion@agent/fix" }),
			json.object({ source = "github", kind = "issue", key = "vocksel/orion#3", id = "R_OLD#3" }),
			json.object({ source = "jira", kind = "issue", key = "ABC-1" }),
		}),
	})

	applyRepositories(
		doc,
		{ { location = "vocksel/orion", host = "github.com", id = "R_1", name = "gummy-galaxy/orion" } },
		"2026-10-25T00:00:00Z"
	)

	local refs = getRefs(doc.nodes[1])
	assert.eq(refs[1].id, "R_1#12")
	assert.eq(refs[1].key, "vocksel/orion#12")
	assert.eq(refs[2].id, "R_1@agent/fix")
	assert.eq(refs[3].id, "R_OLD#3")
	assert.eq(refs[4].id, nil)

	local entry = json.asObject((doc.repositories :: json.Object).R_1)
	assert.eq(if entry then entry.name else nil, "gummy-galaxy/orion")
	assert.eq(if entry then entry.checkedAt else nil, "2026-10-25T00:00:00Z")
end)

test.case("Enterprise repositories keep their host in ids and the directory", function(assert)
	local doc = testing.createDoc({
		card("a", { json.object({ source = "github", kind = "pull", key = "ghe.example.com/team/app#4" }) }),
	})

	applyRepositories(
		doc,
		{ { location = "ghe.example.com/team/app", host = "ghe.example.com", id = "R_2", name = "team/app" } },
		"now"
	)

	assert.eq(getRefs(doc.nodes[1])[1].id, "ghe.example.com/R_2#4")
	assert.eq(json.asObject((doc.repositories :: json.Object)["ghe.example.com/R_2"]) ~= nil, true)
end)
