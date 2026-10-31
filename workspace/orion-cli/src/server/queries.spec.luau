local json = require("@std/json")
local test = require("@std/test")

local loadDoc = require("@root/storage/canvases/loadDoc")
local queries = require("@root/server/queries")
local testing = require("@root/testing")
local writeDoc = require("@root/storage/canvases/writeDoc")

-- A socket that keeps what the server sent it, decoded.
local function createSocket()
	local sent: { json.Object } = {}
	local socket = {
		send = function(_, data: string): number
			local message = json.asObject(json.deserialize(data) :: json.Value) :: json.Object
			table.insert(sent, json.asObject(message.data) :: json.Object)
			return #data
		end,
		close = function() end,
	}

	return socket :: any, sent
end

local function createHub(name: string)
	local root = testing.directory(name)
	writeDoc(
		root,
		testing.createDoc({
			testing.group("ws", "Release"),
			testing.task("ci", "Report release health", "active", "ws"),
			testing.task("pub", "Publish v2.6.0", "todo", "ws"),
		})
	)

	return root, queries.create(root)
end

local function getRowIds(answer: json.Object): string
	local ids: { string } = {}

	for _, value in json.asArray(answer.rows) or {} do
		local row = json.asObject(value) :: json.Object
		table.insert(ids, tostring(row.id))
	end

	return table.concat(ids, " ")
end

local function setStatus(root: string, id: string, status: string)
	local doc = loadDoc(root)

	for _, item in doc.nodes do
		if item.id == id then
			item.data.status = status
		end
	end

	doc.revision += 1
	writeDoc(root, doc)
end

test.case("a query answers right away and again when a change alters it", function(assert)
	local root, hub = createHub("queries-push")
	local socket, sent = createSocket()
	hub.receive(
		socket,
		json.serialize(json.object({ type = "query", id = "table", where = [[kind = "step"]] })),
		"default"
	)
	assert.eq(#sent, 1)
	assert.eq(sent[1].id, "table")
	assert.eq(getRowIds(sent[1]), "ci pub")
	assert.eq(sent[1].total, 2)

	hub.refresh("default")
	assert.eq(#sent, 1)

	setStatus(root, "ci", "done")
	hub.refresh("default")
	assert.eq(#sent, 2)
	assert.eq(getRowIds(sent[2]), "pub")
	assert.eq(type(sent[2].revision), "number")
end)

test.case("sending an id again replaces its query, and unquery drops it", function(assert)
	local root, hub = createHub("queries-replace")
	local socket, sent = createSocket()
	hub.receive(socket, json.serialize(json.object({ type = "query", id = "table" })), "default")
	hub.receive(socket, json.serialize(json.object({ type = "query", id = "table", sort = "-label" })), "default")
	assert.eq(#sent, 2)
	assert.eq(getRowIds(sent[2]), "ci ws pub")

	hub.receive(socket, json.serialize(json.object({ type = "unquery", id = "table" })), "default")
	setStatus(root, "pub", "done")
	hub.refresh("default")
	assert.eq(#sent, 2)
end)

test.case("a failing query answers its error, and closing forgets the socket", function(assert)
	local root, hub = createHub("queries-errors")
	local socket, sent = createSocket()
	hub.receive(socket, json.serialize(json.object({ type = "query", id = "bad", where = "owner = 'me'" })), "default")
	assert.eq(sent[1].id, "bad")
	assert.eq(sent[1].error, "query at column 6: unknown field 'owner'")

	hub.receive(socket, json.serialize(json.object({ type = "query", id = "away", canvas = "nowhere" })), "default")
	assert.eq(sent[2].error, "unknown canvas: nowhere")

	hub.receive(socket, "not json", "default")
	hub.receive(socket, json.serialize(json.object({ type = "query" })), "default")
	assert.eq(#sent, 2)

	hub.receive(socket, json.serialize(json.object({ type = "query", id = "table" })), "default")
	hub.close(socket)
	setStatus(root, "pub", "done")
	hub.refresh("default")
	assert.eq(#sent, 3)
end)
