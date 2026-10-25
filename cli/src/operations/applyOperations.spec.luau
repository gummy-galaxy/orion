local json = require("@std/json")
local test = require("@std/test")

local applyOperations = require("@root/operations/applyOperations")
local copyValue = require("@root/operations/copyValue")
local encodeDocObject = require("@root/store/encodeDocObject")
local parseOperations = require("@root/operations/parseOperations")
local restoreDoc = require("@root/operations/restoreDoc")
local sameValue = require("@root/operations/sameValue")
local testing = require("@root/testing")
local types = require("@root/types")

type Doc = types.Doc

-- Compares the canvas as plain data, since key order isn't part of what a document says.
local function snapshot(doc: Doc): any
	return copyValue(encodeDocObject(doc))
end

local function isSame(doc: Doc, saved: any): boolean
	return sameValue(encodeDocObject(doc), saved)
end

-- A release group holding two cards, one blocking the other, plus a loose card for the insert case.
local function createCanvas(): Doc
	return testing.createDoc({
		testing.group("ws", "Release"),
		testing.task("ci", "Report release health", "active", "ws"),
		testing.task("pub", "Publish v2.6.0", "todo", "ws"),
		testing.task("docs", "Write the notes", "todo", nil),
	}, { { "ci", "pub" } })
end

local function parse(text: string)
	return parseOperations(assert(json.asArray(json.deserialize(text) :: json.Value)))
end

-- Each edit and what it undoes, run one at a time against a fresh canvas.
local SAMPLES: { { name: string, edit: string } } = {
	{ name = "setFields", edit = [=[{"op":"setFields","id":"pub","fields":{"status":"done","label":"Ship it"}}]=] },
	{ name = "place", edit = [=[{"op":"place","id":"pub","x":300,"y":40}]=] },
	{ name = "link", edit = [=[{"op":"link","from":"pub","to":"ci","kind":"related"}]=] },
	{ name = "link with a label", edit = [=[{"op":"link","from":"ci","to":"pub","label":"HTTP"}]=] },
	{ name = "unlink", edit = [=[{"op":"unlink","from":"ci","to":"pub"}]=] },
	{ name = "insert", edit = [=[{"op":"insert","id":"docs","from":"ci","to":"pub"}]=] },
	{ name = "group", edit = [=[{"op":"group","label":"Batch","items":["ci","pub"],"id":"batch"}]=] },
	{ name = "ungroup", edit = [=[{"op":"ungroup","id":"ws"}]=] },
	{ name = "remove", edit = [=[{"op":"remove","id":"ci","reconnect":false}]=] },
	{ name = "removeGroup", edit = [=[{"op":"removeGroup","id":"ws"}]=] },
	{ name = "move", edit = [=[{"op":"move","id":"pub"}]=] },
	{ name = "tidy", edit = [=[{"op":"tidy","id":"ws"}]=] },
	{
		name = "setFields with a pull request",
		edit = [=[{"op":"setFields","id":"pub","fields":{"repo":"vocksel/orion","pr":12}}]=],
	},
	{
		name = "addNote",
		edit = [=[{"op":"addNote","id":"note-new","x":10,"y":20,"group":"ws","data":{"kind":"task","label":"New","itemKind":"note","status":"todo"}}]=],
	},
	{
		name = "setData",
		edit = [=[{"op":"setData","id":"ws","data":{"kind":"cluster","label":"Renamed"}}]=],
	},
	{ name = "resize", edit = [=[{"op":"resize","id":"ws","width":500,"height":300}]=] },
	{ name = "resize clear", edit = [=[{"op":"resize","id":"ws","clear":true}]=] },
	{
		name = "setStickers",
		edit = [=[{"op":"setStickers","stickers":[{"id":"s1","kind":"star","x":1,"y":2,"tilt":3}]}]=],
	},
	{ name = "setStickerLoadout", edit = [=[{"op":"setStickerLoadout","stickerLoadout":["star",null]}]=] },
}

test.case("every operation's inverse restores the document exactly", function(assert)
	for _, sample in SAMPLES do
		local doc = createCanvas()
		local before = snapshot(doc)
		local restores = applyOperations(doc, parse(`[{sample.edit}]`))
		assert.eq(#restores, 1)
		assert.eq(isSame(doc, before), false, `{sample.name} should change the canvas`)
		restoreDoc(doc, restores[1])
		assert.eq(isSame(doc, before), true, `{sample.name} did not undo cleanly`)
	end
end)

test.case("a list applies in order, and undoing each step in reverse restores the start", function(assert)
	local doc = createCanvas()
	local before = snapshot(doc)
	local restores = applyOperations(
		doc,
		parse([=[[
			{"op":"group","label":"Batch","items":["ci","pub"],"id":"batch"},
			{"op":"place","id":"batch","x":10,"y":10},
			{"op":"setFields","id":"pub","fields":{"status":"done"}}
		]]=])
	)
	assert.eq(#restores, 3)
	assert.eq(doc.nodes[#doc.nodes].id, "batch")
	for index = #restores, 1, -1 do
		restoreDoc(doc, restores[index])
	end
	assert.eq(isSame(doc, before), true)
end)

test.case("a list that no longer applies is refused whole and leaves the canvas alone", function(assert)
	local doc = createCanvas()
	local before = snapshot(doc)
	local succeeded, failure = pcall(
		applyOperations,
		doc,
		parse([=[[
			{"op":"setFields","id":"pub","fields":{"status":"done"}},
			{"op":"place","id":"ci","x":5,"y":5},
			{"op":"remove","id":"removed-earlier"}
		]]=])
	)
	assert.eq(succeeded, false)
	assert.eq(type(failure), "table")
	local rejection = failure :: { rejected: boolean, index: number, op: string, message: string }
	assert.eq(rejection.rejected, true)
	assert.eq(rejection.index, 3)
	assert.eq(rejection.op, "remove")
	assert.strContains(rejection.message, "removed-earlier")
	assert.eq(isSame(doc, before), true)
end)

test.case("a group's items must share a parent, and the refusal names the rule", function(assert)
	local doc = createCanvas()
	local succeeded, failure =
		pcall(applyOperations, doc, parse([=[[{"op":"group","label":"Mixed","items":["ci","docs"]}]]=]))
	assert.eq(succeeded, false)
	assert.strContains((failure :: { message: string }).message, "grouped items must share a parent")
	assert.eq(#doc.nodes, 4)
end)

test.case("operations that name a missing item are refused with the id", function(assert)
	local doc = createCanvas()
	local succeeded, failure = pcall(applyOperations, doc, parse([=[[{"op":"ungroup","id":"nope"}]]=]))
	assert.eq(succeeded, false)
	assert.strContains((failure :: { message: string }).message, "nope")
end)

test.case("parsing turns a request into typed edits and names what's wrong", function(assert)
	local linked = parse([=[[{"op":"link","from":"a","to":"b"}]]=])
	assert.eq(linked[1].kind, "blocks")
	assert.eq(linked[1].label, nil)
	assert.eq(parse([=[[{"op":"link","from":"a","to":"b","label":"HTTP"}]]=])[1].label, "HTTP")
	assert.eq(parse([=[[{"op":"move","id":"a"}]]=])[1].group, nil)
	assert.throwsWith("operation 1: unknown operation: explode", function()
		parse([=[[{"op":"explode"}]]=])
	end)
	assert.throwsWith("operation 2: id must be a string", function()
		parse([=[[{"op":"tidy","id":"a"},{"op":"tidy","id":3}]]=])
	end)
	assert.throwsWith("operation 1: id is not a field an operation can set", function()
		parse([=[[{"op":"setFields","id":"a","fields":{"id":"b"}}]]=])
	end)
	assert.throwsWith("operation 1: pr must be a pull request number, or empty", function()
		parse([=[[{"op":"setFields","id":"a","fields":{"pr":"12"}}]]=])
	end)
	assert.throwsWith("operation 1: kind must be blocks or related", function()
		parse([=[[{"op":"link","from":"a","to":"b","kind":"duplicates"}]]=])
	end)
	assert.throwsWith("operation 1: items needs at least one id", function()
		parse([=[[{"op":"group","label":"Empty","items":[]}]]=])
	end)
end)

test.case("a created item joins the canvas and its inverse removes it", function(assert)
	local doc = createCanvas()
	local restores = applyOperations(
		doc,
		parse([=[[
			{"op":"addImage","id":"img","x":4,"y":8,"data":{"kind":"image","label":"Photo","asset":"a.png","canvas":"default"}},
			{"op":"addGroup","id":"batch","x":0,"y":0,"data":{"kind":"cluster","label":"Batch"}},
			{"op":"addCard","id":"inner","x":16,"y":32,"group":"batch","data":{"kind":"task","label":"In","itemKind":"step","status":"todo"}}
		]]=])
	)
	assert.eq(#restores, 3)
	assert.eq(doc.nodes[#doc.nodes].id, "inner")
	assert.eq(doc.nodes[#doc.nodes].parentId, "batch")
	assert.eq(doc.nodes[#doc.nodes - 2].type, "image")
	for index = #restores, 1, -1 do
		restoreDoc(doc, restores[index])
	end
	assert.eq(#doc.nodes, 4)
end)

test.case("creating over an id that's taken, or under a missing or non-group parent, is refused", function(assert)
	local doc = createCanvas()
	local before = snapshot(doc)
	local taken = {
		succeeded = pcall(applyOperations, doc, parse([=[[{"op":"addCard","id":"pub","x":0,"y":0,"data":{}}]]=])),
	}
	local missingParent = {
		succeeded = pcall(
			applyOperations,
			doc,
			parse([=[[{"op":"addCard","id":"x","x":0,"y":0,"group":"nope","data":{}}]]=])
		),
	}
	local itemParent = {
		succeeded = pcall(
			applyOperations,
			doc,
			parse([=[[{"op":"addCard","id":"x","x":0,"y":0,"group":"pub","data":{}}]]=])
		),
	}
	assert.eq(taken.succeeded, false)
	assert.eq(missingParent.succeeded, false)
	assert.eq(itemParent.succeeded, false)
	assert.eq(isSame(doc, before), true)
end)

test.case("a sticker list is restored only when the list changed", function(assert)
	local doc = createCanvas()
	local restores = applyOperations(doc, parse([=[[{"op":"place","id":"pub","x":1,"y":1}]]=]))
	assert.eq(restores[1].stickers, nil)
	assert.eq(restores[1].stickerLoadout, nil)
	local sticker = applyOperations(
		doc,
		parse([=[[{"op":"setStickers","stickers":[{"id":"s1","kind":"star","x":1,"y":2,"tilt":0}]}]]=])
	)
	assert.eq(sticker[1].stickers ~= nil, true)
	assert.eq(#(json.asArray(encodeDocObject(doc).stickers :: json.Value) :: json.Array), 1)
	restoreDoc(doc, sticker[1])
	assert.eq(encodeDocObject(doc).stickers, nil)
end)

test.case("a resize keeps the stored size, and clear drops it", function(assert)
	local doc = createCanvas()
	local restores = applyOperations(doc, parse([=[[{"op":"resize","id":"ws","width":500,"height":300}]]=]))
	assert.eq(doc.nodes[1].width, 500)
	assert.eq(doc.nodes[1].height, 300)
	applyOperations(doc, parse([=[[{"op":"resize","id":"ws","clear":true}]]=]))
	assert.eq(doc.nodes[1].width, nil)
	restoreDoc(doc, restores[1])
	assert.eq(doc.nodes[1].width, 400)
end)

test.case("parsing checks the new operations' fields", function(assert)
	assert.throwsWith("operation 1: addNote needs data.itemKind to be note", function()
		parse([=[[{"op":"addNote","id":"a","x":0,"y":0,"data":{"itemKind":"step"}}]]=])
	end)
	assert.throwsWith("operation 1: addCard is for work items; use addNote for a note", function()
		parse([=[[{"op":"addCard","id":"a","x":0,"y":0,"data":{"itemKind":"note"}}]]=])
	end)
	assert.throwsWith("operation 1: data must be an object", function()
		parse([=[[{"op":"setData","id":"a","data":"nope"}]]=])
	end)
	assert.throwsWith("operation 1: width must be a number", function()
		parse([=[[{"op":"resize","id":"a","width":"wide","height":3}]]=])
	end)
	assert.throwsWith("operation 1: stickers must be an array", function()
		parse([=[[{"op":"setStickers","stickers":{}}]]=])
	end)
	assert.eq(parse([=[[{"op":"resize","id":"a","clear":true}]]=])[1].width, nil)
end)

test.case("setFields resolves a pull request against the card's repo and takes it off when empty", function(assert)
	local doc = createCanvas()
	applyOperations(doc, parse([=[[{"op":"setFields","id":"pub","fields":{"repo":"vocksel/orion","pr":12}}]]=]))
	local pub = doc.nodes[3]
	local refs = pub.data.refs :: any
	assert.eq(pub.data.itemKind, "pr")
	assert.eq(#refs, 1)
	assert.eq(refs[1].key, "vocksel/orion#12")
	assert.eq(refs[1].url, "https://github.com/vocksel/orion/pull/12")

	applyOperations(doc, parse([=[[{"op":"setFields","id":"pub","fields":{"pr":""}}]]=]))
	assert.eq(pub.data.refs, nil)
	assert.eq(pub.data.itemKind, "placeholder")

	local succeeded, failure =
		pcall(applyOperations, doc, parse([=[[{"op":"setFields","id":"docs","fields":{"pr":3}}]]=]))
	assert.eq(succeeded, false)
	assert.strContains((failure :: { message: string }).message, '"docs" needs a repo before it takes a pull request')
end)

test.case("setFields keeps a pull request's facts when the number doesn't change", function(assert)
	local doc = createCanvas()
	applyOperations(doc, parse([=[[{"op":"setFields","id":"pub","fields":{"repo":"vocksel/orion","pr":12}}]]=]))
	local pub = doc.nodes[3];
	(pub.data.refs :: any)[1].status = "open"
	applyOperations(doc, parse([=[[{"op":"setFields","id":"pub","fields":{"label":"Ship","pr":12}}]]=]))
	assert.eq((pub.data.refs :: any)[1].status, "open")
end)

-- The message a refused list gives, which applyOperations raises inside a rejection.
local function refuse(doc: Doc, text: string): string
	local succeeded, failure = pcall(applyOperations, doc, parse(text))
	assert(not succeeded, "the list should be refused")
	return (failure :: { message: string }).message
end

test.case("setData refuses cards, so card edits go through the field rules", function(assert)
	local message = refuse(
		createCanvas(),
		[=[[{"op":"setData","id":"pub","data":{"kind":"task","label":"x","itemKind":"step","status":"done"}}]]=]
	)
	assert.eq(message, '"pub" is a card; change its fields with setFields')
end)

test.case("closeOut closes out one finished card and leaves its chain waiting", function(assert)
	local doc = testing.createDoc({
		testing.task("a", "A", "active"),
		testing.task("b", "B", "done", nil, { celebrate = true }),
	}, { { "a", "b" } })
	applyOperations(
		doc,
		parse([=[[{"op":"setFields","id":"a","fields":{"status":"done"}},{"op":"closeOut","id":"a"}]]=])
	)
	assert.eq(doc.nodes[1].data.celebrate, false)
	assert.eq(doc.nodes[2].data.celebrate, true)

	local message =
		refuse(doc, [=[[{"op":"setFields","id":"b","fields":{"status":"todo"}},{"op":"closeOut","id":"b"}]]=])
	assert.eq(message, `"b" isn't done yet; finish it before closing it out`)
end)

test.case("an added card never starts out waiting to be closed out", function(assert)
	local doc = createCanvas()
	applyOperations(
		doc,
		parse(
			[=[[{"op":"addCard","id":"copy","x":0,"y":0,"data":{"kind":"task","label":"Copy","itemKind":"step","status":"done","celebrate":true}}]]=]
		)
	)
	assert.eq(doc.nodes[#doc.nodes].data.celebrate, nil)
end)
