local json = require("@std/json")
local test = require("@std/test")

local getRefs = require("@root/refs/getRefs")
local healRefKeys = require("@root/github/healRefKeys")
local testing = require("@root/testing")

local function card(id: string, refs: { json.Object }, repo: string?): any
	return testing.task(id, id, "active", nil, json.object({ refs = refs, repo = repo }))
end

local function moved(doc: any)
	doc.repositories = json.object({ R_1 = json.object({ name = "gummy-galaxy/orion", checkedAt = "now" }) })
	return doc
end

test.case("refs take their repository's current name and keep their number, branch, and URL", function(assert)
	local doc = moved(testing.createDoc({
		card("a", {
			json.object({
				source = "github",
				kind = "pull",
				key = "vocksel/orion#12",
				id = "R_1#12",
				url = "https://github.com/vocksel/orion/pull/12",
			}),
			json.object({ source = "hop", kind = "branch", key = "Vocksel/Orion@agent/fix", id = "R_1@agent/fix" }),
		}, "vocksel/orion"),
	}))

	local moves = healRefKeys(doc)

	local refs = getRefs(doc.nodes[1])
	assert.eq(refs[1].key, "gummy-galaxy/orion#12")
	assert.eq(refs[1].url, "https://github.com/gummy-galaxy/orion/pull/12")
	assert.eq(refs[2].key, "gummy-galaxy/orion@agent/fix")
	assert.eq(doc.nodes[1].data.repo, "gummy-galaxy/orion")
	assert.eq(#moves, 1)
	assert.eq(moves[1].from, "vocksel/orion")
	assert.eq(moves[1].to, "gummy-galaxy/orion")
end)

test.case("refs with no id, or whose repository the directory doesn't know, stay as they are", function(assert)
	local doc = moved(testing.createDoc({
		card("a", {
			json.object({ source = "github", kind = "pull", key = "vocksel/orion#12" }),
			json.object({ source = "github", kind = "pull", key = "flipbook-labs/flipbook#2", id = "R_9#2" }),
		}),
	}))

	assert.eq(#healRefKeys(doc), 0)
	local refs = getRefs(doc.nodes[1])
	assert.eq(refs[1].key, "vocksel/orion#12")
	assert.eq(refs[2].key, "flipbook-labs/flipbook#2")
end)

test.case("a card left with the same ref twice keeps the first", function(assert)
	local doc = moved(testing.createDoc({
		card("a", {
			json.object({ source = "github", kind = "pull", key = "vocksel/orion#12", id = "R_1#12", status = "open" }),
			json.object({ source = "github", kind = "pull", key = "gummy-galaxy/orion#12", id = "R_1#12" }),
		}),
	}))

	healRefKeys(doc)

	local refs = getRefs(doc.nodes[1])
	assert.eq(#refs, 1)
	assert.eq(refs[1].status, "open")
end)

test.case("Enterprise refs keep their host", function(assert)
	local doc = testing.createDoc({
		card("a", {
			json.object({
				source = "github",
				kind = "pull",
				key = "ghe.example.com/team/app#4",
				id = "ghe.example.com/R_2#4",
			}),
		}),
	})
	doc.repositories = json.object({ ["ghe.example.com/R_2"] = json.object({ name = "platform/app" }) })

	healRefKeys(doc)

	assert.eq(getRefs(doc.nodes[1])[1].key, "ghe.example.com/platform/app#4")
end)
