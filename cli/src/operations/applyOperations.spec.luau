local json = require("@std/json")
local test = require("@std/test")

local applyOperations = require("@root/operations/applyOperations")
local copyValue = require("@root/operations/copyValue")
local parseOperations = require("@root/operations/parseOperations")
local restoreDoc = require("@root/operations/restoreDoc")
local sameValue = require("@root/operations/sameValue")
local store = require("@root/store")
local testing = require("@root/testing")
local types = require("@root/types")

type Doc = types.Doc

-- Compares the canvas as plain data, since key order isn't part of what a document says.
local function snapshot(doc: Doc): any
	return copyValue(store.toObject(doc))
end

local function isSame(doc: Doc, saved: any): boolean
	return sameValue(store.toObject(doc), saved)
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
	{ name = "unlink", edit = [=[{"op":"unlink","from":"ci","to":"pub"}]=] },
	{ name = "insert", edit = [=[{"op":"insert","id":"docs","from":"ci","to":"pub"}]=] },
	{ name = "group", edit = [=[{"op":"group","label":"Batch","items":["ci","pub"],"id":"batch"}]=] },
	{ name = "ungroup", edit = [=[{"op":"ungroup","id":"ws"}]=] },
	{ name = "remove", edit = [=[{"op":"remove","id":"ci","reconnect":false}]=] },
	{ name = "removeGroup", edit = [=[{"op":"removeGroup","id":"ws"}]=] },
	{ name = "move", edit = [=[{"op":"move","id":"pub"}]=] },
	{ name = "tidy", edit = [=[{"op":"tidy","id":"ws"}]=] },
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
	assert.throwsWith("operation 1: pr must be a number", function()
		parse([=[[{"op":"setFields","id":"a","fields":{"pr":"12"}}]]=])
	end)
	assert.throwsWith("operation 1: kind must be blocks or related", function()
		parse([=[[{"op":"link","from":"a","to":"b","kind":"duplicates"}]]=])
	end)
	assert.throwsWith("operation 1: items needs at least one id", function()
		parse([=[[{"op":"group","label":"Empty","items":[]}]]=])
	end)
end)
