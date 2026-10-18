local test = require("@std/test")

local addPlacement = require("@root/graph/addPlacement")
local applyOperation = require("@root/operations/applyOperation")
local decodeDoc = require("@root/store/decodeDoc")
local derive = require("@root/graph/derive")
local encodeDoc = require("@root/store/encodeDoc")
local findItem = require("@root/graph/findItem")
local getItem = require("@root/graph/getItem")
local getPlacements = require("@root/graph/getPlacements")
local removeGroup = require("@root/graph/removeGroup")
local removeItem = require("@root/graph/removeItem")
local removePlacement = require("@root/graph/removePlacement")
local restoreDoc = require("@root/operations/restoreDoc")
local testing = require("@root/testing")

local task = testing.task

local function createDoc()
	return testing.createDoc({
		testing.group("auth", "Auth"),
		testing.group("release", "Release"),
		task("login", "Login flow", "active", "auth"),
		task("ship", "Ship it", "todo", "release"),
	}, { { "login", "ship" } })
end

test.case("a card placed twice keeps one record, and copies read its facts", function(assert)
	local doc = createDoc()
	local placement = addPlacement(doc, "login", "release")

	assert.eq(placement.id, "login-copy")
	assert.eq(#getPlacements(doc, "login"), 2)
	assert.eq(getItem(doc, "release").data.layout, "refit")

	local derived = derive(doc)
	assert.eq(derived.status["login-copy"], derived.status.login)
	assert.eq(derived.groups.release.total, 2)

	assert.throws(function()
		addPlacement(doc, "login", "auth")
	end)
	assert.throws(function()
		addPlacement(doc, "auth", "release")
	end)
end)

test.case("placements survive a write and a read", function(assert)
	local doc = createDoc()
	addPlacement(doc, "login", "release", { x = 10, y = 20 })
	local read = decodeDoc(encodeDoc(doc))
	local placements = read.placements or {}

	assert.eq(#placements, 1)
	assert.eq(placements[1].node, "login")
	assert.eq(placements[1].parentId, "release")
	assert.eq(placements[1].position.y, 20)
end)

test.case("removing a placement keeps the card, and removing its own record moves a copy into it", function(assert)
	local doc = createDoc()
	addPlacement(doc, "login", "release")
	removePlacement(doc, "login")

	assert.eq(getItem(doc, "login").parentId, "release")
	assert.eq(doc.placements, nil)
	assert.eq(findItem(doc, "auth"), nil)
	assert.throws(function()
		removePlacement(doc, "login")
	end)
end)

test.case("removing the card removes every placement", function(assert)
	local doc = createDoc()
	addPlacement(doc, "ship", "auth")
	removeItem(doc, "ship")

	assert.eq(doc.placements, nil)
	assert.eq(findItem(doc, "release"), nil)
	assert.neq(findItem(doc, "auth"), nil)
end)

test.case("removing a group keeps cards still shown elsewhere", function(assert)
	local doc = createDoc()
	addPlacement(doc, "login", "release")
	removeGroup(doc, "auth")

	assert.eq(getItem(doc, "login").parentId, "release")
	assert.eq(doc.placements, nil)
end)

test.case("placement operations apply and undo", function(assert)
	local doc = createDoc()
	local restore =
		applyOperation(doc, { op = "addPlacement", id = "copy", node = "ship", group = "auth", x = 0, y = 0 })

	assert.eq(#getPlacements(doc, "ship"), 2)
	applyOperation(doc, { op = "movePlacement", id = "copy", x = 5, y = 6 })
	assert.eq((doc.placements :: any)[1].parentId, nil)
	restoreDoc(doc, restore)
	assert.eq(doc.placements, nil)
end)
