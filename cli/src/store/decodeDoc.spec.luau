local json = require("@std/json")
local test = require("@std/test")

local decodeDoc = require("@root/store/decodeDoc")
local encodeDoc = require("@root/store/encodeDoc")
local findRef = require("@root/refs/findRef")
local getRefs = require("@root/refs/getRefs")

test.case("decode migrates every legacy card field and remains stable on reread", function(assert)
	local doc = decodeDoc([[{
		"version":1,"revision":3,
		"settings":{"githubOwner":"Vocksel","future":"kept","sources":[{"id":"hop-local","kind":"hop"}]},
		"nodes":[
			{"id":"pull","type":"task","data":{"repo":"Orion","pr":12,"host":"github.example.com","branch":"feature/A","github":{"state":"OPEN","draft":true,"url":"https://example/pull/12","updatedAt":"yesterday"},"activity":{"lastActiveAt":"today","sessions":["Review"]},"sources":["hop-local"]}},
			{"id":"bare","type":"task","data":{"repo":"Orion","pr":13,"issue":8}},
			{"id":"jira","type":"task","data":{"external":{"source":"jira","key":"ORN-1","url":"https://jira/ORN-1","status":"Done","isDone":true,"updatedAt":"today","details":{"type":"Task"}}}},
			{"id":"branch","type":"task","data":{"repo":"Orion","branch":"feature/B","activity":{"sessions":[]}}},
			{"id":"group","type":"cluster","data":{"repo":"short"}}
		],"links":[],"future":{"kept":true}
	}]])
	assert.eq(doc.version, 2)
	local pull = doc.nodes[1]
	assert.eq(pull.data.repo, "Vocksel/Orion")
	assert.eq((findRef(pull, "pull") :: any).key, "github.example.com/Vocksel/Orion#12")
	assert.eq((findRef(pull, "pull") :: any).url, "https://example/pull/12")
	assert.eq((findRef(pull, "pull") :: any).status, "draft")
	assert.eq((findRef(pull, "branch") :: any).source, "hop-local")
	assert.eq((findRef(pull, "branch") :: any).key, "github.example.com/Vocksel/Orion@feature/A")
	assert.eq(pull.data.pr, nil)
	assert.eq(pull.data.github, nil)
	assert.eq(pull.data.activity, nil)
	assert.eq(pull.data.sources, nil)
	assert.eq((findRef(doc.nodes[2], "pull") :: any).url, "https://github.com/Vocksel/Orion/pull/13")
	assert.eq((findRef(doc.nodes[2], "issue") :: any).key, "Vocksel/Orion#8")
	assert.eq((findRef(doc.nodes[3], "issue") :: any).isDone, true)
	assert.eq((findRef(doc.nodes[4], "branch") :: any).source, "hop")
	assert.eq(doc.nodes[4].data.itemKind, "placeholder")
	assert.eq(doc.nodes[5].data.repo, "short")
	local encoded = encodeDoc(doc)
	local reread = decodeDoc(encoded)
	assert.eq(#getRefs(reread.nodes[1]), 2)
	assert.eq(#getRefs(reread.nodes[2]), 2)
	assert.eq(reread.nodes[1].data.repo, "Vocksel/Orion")
	local root = json.asObject(json.deserialize(encoded) :: json.Value)
	local settings = if root then json.asObject(root.settings) else nil
	assert.eq(settings and settings.githubOwner, nil)
	assert.eq(settings and settings.future, "kept")
	assert.eq(root and root.version, 2)
end)

test.case("decode leaves clean version-two cards unchanged and migrates stray legacy fields", function(assert)
	local doc = decodeDoc(
		[[{"version":2,"settings":{"githubOwner":"Vocksel"},"nodes":[{"id":"clean","type":"task","data":{"repo":"short","refs":[{"source":"jira","kind":"issue","key":"ORN-1"}]}},{"id":"legacy","type":"task","data":{"repo":"orion","pr":3}}],"links":[]}]]
	)
	assert.eq(doc.nodes[1].data.repo, "short")
	assert.eq((findRef(doc.nodes[1], "issue") :: any).key, "ORN-1")
	assert.eq(doc.nodes[2].data.repo, "Vocksel/orion")
	assert.eq((findRef(doc.nodes[2], "pull") :: any).key, "Vocksel/orion#3")
end)

test.case("decode uses the first GitHub source owner for short legacy repos", function(assert)
	local doc = decodeDoc(
		[[{"version":2,"settings":{"sources":[{"id":"jira","kind":"jira"},{"id":"gh-first","kind":"github","owners":["Roblox","Vocksel"]},{"id":"gh-second","kind":"github","owners":["Other"]}]},"nodes":[{"id":"a","type":"task","data":{"repo":"avatar","pr":12}}],"links":[]}]]
	)
	assert.eq(doc.nodes[1].data.repo, "Roblox/avatar")
	assert.eq((findRef(doc.nodes[1], "pull") :: any).key, "Roblox/avatar#12")

	local default = decodeDoc(
		[[{"version":1,"settings":{"sources":[{"id":"jira","kind":"jira"}]},"nodes":[{"id":"a","type":"task","data":{"repo":"avatar"}}],"links":[]}]]
	)
	assert.eq(default.nodes[1].data.repo, "flipbook-labs/avatar")
end)

test.case("decode migrates typed sources in a version-one document", function(assert)
	local doc = decodeDoc([[{
		"version":1,
		"settings":{"sources":[{"id":"gh-vocksel","kind":"github","owners":["Vocksel"]},{"id":"hop-local","kind":"hop"}]},
		"nodes":[
			{"id":"repo","type":"task","data":{"sources":[{"kind":"github-pr","repo":"orion"}]}},
			{"id":"pull","type":"task","data":{"sources":[{"kind":"github-pr","repo":"orion","number":37,"branch":"agent/sticker-wheel","via":"gh-vocksel","state":{"state":"MERGED","draft":false,"url":"https://github.com/Vocksel/orion/pull/37","updatedAt":"now","mergeStateStatus":"UNKNOWN"}}]}},
			{"id":"issue","type":"task","data":{"sources":[{"kind":"github-issue","repo":"flipbook","number":621,"via":"gh-vocksel"}]}},
			{"id":"hop","type":"task","data":{"sources":["hop-local",{"kind":"hop","repo":"changewrite","branch":"release-branch-config","state":{"sessions":[],"lastActiveAt":"2026-10-04T02:32:28Z"}}]}}
		],"links":[]
	}]])
	assert.eq(doc.version, 2)
	assert.eq(doc.nodes[1].data.repo, "Vocksel/orion")
	assert.eq(#getRefs(doc.nodes[1]), 0)
	assert.eq((findRef(doc.nodes[2], "pull") :: any).key, "Vocksel/orion#37")
	assert.eq((findRef(doc.nodes[2], "pull") :: any).isDone, true)
	assert.eq((findRef(doc.nodes[2], "pull") :: any).details.mergeStateStatus, "UNKNOWN")
	assert.eq((findRef(doc.nodes[3], "issue") :: any).key, "Vocksel/flipbook#621")
	assert.eq((findRef(doc.nodes[4], "branch") :: any).source, "hop-local")
	assert.eq((findRef(doc.nodes[4], "branch") :: any).key, "Vocksel/changewrite@release-branch-config")
	for _, item in doc.nodes do
		assert.eq(item.data.sources, nil)
	end
	local reread = decodeDoc(encodeDoc(doc))
	assert.eq((findRef(reread.nodes[2], "pull") :: any).key, "Vocksel/orion#37")
end)

test.case("decode moves an image's workspace to canvas", function(assert)
	local doc = decodeDoc([[{
		"version":2,"revision":1,
		"nodes":[{"id":"picture","type":"image","position":{"x":0,"y":0},"data":{"kind":"image","label":"Picture","asset":"a.png","workspace":"planning"}}],
		"links":[]
	}]])
	assert.eq(doc.nodes[1].data.canvas, "planning")
	assert.eq(doc.nodes[1].data.workspace, nil)
end)
