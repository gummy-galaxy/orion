local json = require("@std/json")
local test = require("@std/test")

local decodeDoc = require("@root/store/decodeDoc")
local encodeDoc = require("@root/store/encodeDoc")

test.case("encodeDoc round-trips stack origins without adding one to hand-made links", function(assert)
	local doc = decodeDoc(
		[[{"version":2,"nodes":[],"links":[{"id":"a>b","from":"a","to":"b","kind":"blocks","origin":"stack"},]]
			.. [[{"id":"b>c","from":"b","to":"c","kind":"related"}]}]]
	)
	assert.eq(doc.links[1].origin, "stack")
	assert.eq(doc.links[2].origin, nil)
	local encoded = json.asObject(json.deserialize(encodeDoc(doc)) :: json.Value)
	local links = if encoded then json.asArray(encoded.links) else nil
	local stack = if links then json.asObject(links[1]) else nil
	local manual = if links then json.asObject(links[2]) else nil
	assert.eq(stack and stack.origin, "stack")
	assert.eq(manual and manual.origin, nil)
end)

test.case("encodeDoc round-trips link labels", function(assert)
	local doc = decodeDoc(
		[[{"version":2,"nodes":[],"links":[{"id":"a>b","from":"a","to":"b","kind":"blocks","label":"HTTP"},]]
			.. [[{"id":"b>c","from":"b","to":"c","kind":"blocks"}]}]]
	)
	assert.eq(doc.links[1].label, "HTTP")
	assert.eq(doc.links[2].label, nil)
	local encoded = json.asObject(json.deserialize(encodeDoc(doc)) :: json.Value)
	local links = if encoded then json.asArray(encoded.links) else nil
	local labeled = if links then json.asObject(links[1]) else nil
	local plain = if links then json.asObject(links[2]) else nil
	assert.eq(labeled and labeled.label, "HTTP")
	assert.eq(plain and plain.label, nil)
end)

test.case("encodeDoc round-trips top-level GitHub data and unknown fields", function(assert)
	local doc = decodeDoc(
		[[{"version":2,"revision":0,"settings":{"githubOwner":"flipbook-labs","futureSetting":{"kept":true}},]]
			.. [["nodes":[],"links":[],"github":{"viewer":"vocksel","checkedAt":"now","unplaced":[]},]]
			.. [["future":{"kept":true}}]]
	)
	doc.settings.sources = { { id = "hop", kind = "hop" } }
	local encoded = json.asObject(json.deserialize(encodeDoc(doc)) :: json.Value)
	local github = if encoded then json.asObject(encoded.github) else nil
	local future = if encoded then json.asObject(encoded.future) else nil
	local settings = if encoded then json.asObject(encoded.settings) else nil
	local futureSetting = if settings then json.asObject(settings.futureSetting) else nil
	local sources = if settings then json.asArray(settings.sources) else nil
	assert.eq(github and github.viewer, "vocksel")
	assert.eq(future and future.kept, true)
	assert.eq(futureSetting and futureSetting.kept, true)
	assert.eq(sources and #sources, 1)
	assert.eq(settings and settings.githubOwner, nil)
	assert.eq(encoded and encoded.version, 2)
end)
