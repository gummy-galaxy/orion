local json = require("@std/json")
local test = require("@std/test")

local decodeDoc = require("@root/store/decodeDoc")
local encodeDoc = require("@root/store/encodeDoc")
local findRef = require("@root/refs/findRef")

local VERSION_ONE_MESSAGE = "This canvas was saved as data version 1, which Orion no longer reads."

test.case("decode refuses a version 1 document and says how to upgrade it", function(assert)
	for _, text in
		{
			[[{"version":1,"settings":{},"nodes":[{"id":"a","type":"task","data":{"repo":"orion","pr":12}}],"links":[]}]],
			[[{"nodes":[],"links":[]}]],
		}
	do
		local didDecode, failure = pcall(decodeDoc, text)
		assert.eq(didDecode, false)
		assert.strContains(tostring(failure), VERSION_ONE_MESSAGE)
		assert.strContains(tostring(failure), "To upgrade it")
	end
end)

test.case("decode reads a version 2 document and keeps unknown fields through a reread", function(assert)
	local doc = decodeDoc([[{
		"version":2,"revision":3,
		"settings":{"githubOwner":"Vocksel","future":"kept","sources":[{"id":"hop-local","kind":"hop"}]},
		"nodes":[
			{"id":"pull","type":"task","data":{"repo":"Vocksel/Orion","refs":[{"source":"github","kind":"pull","key":"Vocksel/Orion#12","status":"draft"}]}},
			{"id":"jira","type":"task","data":{"refs":[{"source":"jira","kind":"issue","key":"ORN-1","isDone":true}]}},
			{"id":"group","type":"cluster","data":{"repo":"short"}}
		],"links":[],"future":{"kept":true}
	}]])
	assert.eq(doc.version, 2)
	assert.eq(doc.revision, 3)
	assert.eq((findRef(doc.nodes[1], "pull") :: any).key, "Vocksel/Orion#12")
	assert.eq((findRef(doc.nodes[2], "issue") :: any).isDone, true)
	assert.eq(doc.nodes[3].data.repo, "short")

	local encoded = encodeDoc(doc)
	local reread = decodeDoc(encoded)
	assert.eq((findRef(reread.nodes[1], "pull") :: any).key, "Vocksel/Orion#12")
	local root = json.asObject(json.deserialize(encoded) :: json.Value)
	local settings = if root then json.asObject(root.settings) else nil
	assert.eq(settings and settings.githubOwner, nil)
	assert.eq(settings and settings.future, "kept")
	assert.eq(root and root.version, 2)
	local future = if root then json.asObject(root.future) else nil
	assert.eq(future and future.kept, true)
end)
