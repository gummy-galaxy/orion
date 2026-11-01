local json = require("@std/json")
local net = require("@lute/net/server")
local test = require("@std/test")

local createRouter = require("@root/server/routes/createRouter")
local testing = require("@root/testing")
local writeDoc = require("@root/storage/canvases/writeDoc")

local function createRequest(method: string, value: json.Object?, canvas: string?): net.ReceivedRequest
	return {
		method = method,
		path = "/api/query",
		body = if value then json.serialize(value) else "",
		query = {} :: { [string]: string },
		headers = if canvas then { ["x-orion-canvas"] = canvas } else {},
	}
end

local function decodeResponse(response): json.Object
	return assert(json.asObject(json.deserialize(response.body) :: json.Value))
end

local function createTestRouter(name: string)
	local root = testing.directory(name)
	local status = json.object({ state = "idle" })
	local router = createRouter(root, "default", {
		getStatus = function()
			return status
		end,

		runAsync = function()
			return status
		end,
	}, function() end)

	writeDoc(
		root,
		testing.createDoc({
			testing.group("ws", "Release"),
			testing.task("ci", "Report release health", "active", "ws"),
			testing.task("pub", "Publish v2.6.0", "todo", "ws"),
			testing.task("old", "Archive the old site", "done", "ws"),
		}, { { "ci", "pub" } })
	)

	return router
end

local function getRowIds(body: json.Object): string
	local ids: { string } = {}

	for _, value in json.asArray(body.rows) or {} do
		local row = assert(json.asObject(value))
		table.insert(ids, tostring(row.id))
	end

	return table.concat(ids, " ")
end

test.case("POST answers a sorted page of rows with derived fields", function(assert)
	local router = createTestRouter("query-route-page")
	local response = router.handleAsync(
		createRequest(
			"POST",
			json.object({ where = [[group = "ws"]], sort = "label", offset = 1, limit = 1, all = true })
		)
	)
	assert.eq(response.status, 200)

	local body = decodeResponse(response)
	assert.eq(getRowIds(body), "pub")
	assert.eq(body.total, 3)
	assert.eq(body.offset, 1)
	assert.eq(body.canvas, "default")
	assert.eq(type(body.revision), "number")

	local row = json.asObject((json.asArray(body.rows) :: json.Array)[1]) :: json.Object
	assert.eq(row.status, "blocked")
	assert.eq(row.groupLabel, "Release")
end)

test.case("a blank where matches every open node", function(assert)
	local router = createTestRouter("query-route-blank")
	local body = decodeResponse(router.handleAsync(createRequest("POST", json.object({ where = "  " }))))
	assert.eq(getRowIds(body), "ws ci pub")
	assert.eq(getRowIds(decodeResponse(router.handleAsync(createRequest("POST", json.object({}))))), "ws ci pub")
end)

test.case("bad requests answer 400 with the parser's error", function(assert)
	local router = createTestRouter("query-route-errors")
	local response = router.handleAsync(createRequest("POST", json.object({ where = "owner = 'me'" })))
	assert.eq(response.status, 400)
	assert.eq(decodeResponse(response).error, "query at column 6: unknown field 'owner'")

	response = router.handleAsync(createRequest("POST", json.object({ limit = "ten" })))
	assert.eq(response.status, 400)
	assert.eq(decodeResponse(response).error, "limit must be a number")

	response = router.handleAsync(createRequest("POST", json.object({ sort = "owner" })))
	assert.eq(decodeResponse(response).error, "sort: unknown field 'owner'")
end)

test.case("unknown canvases answer 404, and other methods 405", function(assert)
	local router = createTestRouter("query-route-canvas")
	assert.eq(router.handleAsync(createRequest("POST", json.object({}), "nowhere")).status, 404)
	assert.eq(router.handleAsync(createRequest("GET")).status, 405)
end)
