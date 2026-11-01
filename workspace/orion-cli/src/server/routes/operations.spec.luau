local json = require("@std/json")
local net = require("@lute/net/server")
local test = require("@std/test")

local createRouter = require("@root/server/routes/createRouter")
local loadDoc = require("@root/storage/canvases/loadDoc")
local testing = require("@root/testing")
local writeDoc = require("@root/storage/canvases/writeDoc")

local function createRequest(method: string, route: string, value: json.Object?): net.ReceivedRequest
	return {
		method = method,
		path = route,
		body = if value then json.serialize(value) else "",
		query = {} :: { [string]: string },
		headers = {},
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
		}, { { "ci", "pub" } })
	)

	return root, router
end

-- The saved file's bytes, so a refused change is shown to leave the file alone.
local function savedText(root: string): string
	return testing.readCanvasText(root)
end

local function edits(text: string): json.Object
	return json.asObject(json.deserialize(text) :: json.Value) :: json.Object
end

test.case("POST applies a list as one revision", function(assert)
	local root, router = createTestRouter("operations-apply")
	local response = router.handleAsync(
		createRequest(
			"POST",
			"/api/operations",
			edits(
				[[{"operations":[{"op":"setFields","id":"pub","fields":{"status":"done"}},{"op":"place","id":"ci",]]
					.. [["x":40,"y":60}]}]]
			)
		)
	)
	local body = decodeResponse(response)
	assert.eq(response.status, 200)
	assert.eq(body.revision, 1)
	assert.eq(body.applied, 2)
	local doc = loadDoc(root)
	assert.eq(doc.revision, 1)
	assert.eq(doc.nodes[3].data.status, "done")
	assert.eq(doc.nodes[2].position.x, 40)
end)

test.case("POST finishes and closes out a card in one write, and answers with the chain", function(assert)
	local root, router = createTestRouter("operations-close-out")
	local response = router.handleAsync(
		createRequest(
			"POST",
			"/api/operations",
			edits(
				[[{"operations":[{"op":"setFields","id":"ci","fields":{"status":"done"}},{"op":"chainClose","id":"ci"}]}]]
			)
		)
	)
	local body = decodeResponse(response)
	assert.eq(response.status, 200)
	local results = json.asArray(body.results) :: json.Array
	assert.eq(results[1], json.null)
	local answer = json.asObject(results[2]) :: json.Object
	local closed = json.asArray(answer.closed) :: json.Array
	local first = json.asObject(closed[1]) :: json.Object
	assert.eq(#closed, 1)
	assert.eq(first.id, "ci")
	assert.eq(first.hops, 0)
	assert.eq(#(json.asArray(answer.passed) :: json.Array), 0)
	-- Closed out in the same write, so the finished card never starts waiting.
	assert.eq(loadDoc(root).nodes[2].data.celebrate, nil)
end)

test.case("POST with a stale baseRevision is refused and leaves the file alone", function(assert)
	local root, router = createTestRouter("operations-stale")
	router.handleAsync(createRequest("POST", "/api/operations", edits([[{"operations":[{"op":"tidy","id":"ws"}]}]])))
	local before = savedText(root)
	local response = router.handleAsync(
		createRequest(
			"POST",
			"/api/operations",
			edits([[{"baseRevision":0,"operations":[{"op":"setFields","id":"pub","fields":{"status":"done"}}]}]])
		)
	)
	assert.eq(response.status, 409)
	assert.eq(decodeResponse(response).error, "revision changed")
	assert.eq(decodeResponse(response).revision, 1)
	assert.eq(savedText(root), before)
end)

test.case("POST refuses the whole list when one edit no longer applies", function(assert)
	local root, router = createTestRouter("operations-rejected")
	local before = savedText(root)
	local response = router.handleAsync(
		createRequest(
			"POST",
			"/api/operations",
			edits(
				[[{"operations":[{"op":"setFields","id":"pub","fields":{"status":"done"}},{"op":"ungroup","id":"gone"}]}]]
			)
		)
	)
	local body = decodeResponse(response)
	assert.eq(response.status, 409)
	assert.eq(body.index, 2)
	assert.eq(body.op, "ungroup")
	assert.strContains(body.error :: string, "gone")
	assert.eq(loadDoc(root).revision, 0)
	assert.eq(savedText(root), before)
end)

test.case("POST rejects malformed requests before touching the document", function(assert)
	local root, router = createTestRouter("operations-malformed")
	local before = savedText(root)
	local cases = {
		[[{"operations":[]}]],
		[[{"operations":[{"op":"explode"}]}]],
		[[{"operations":"tidy"}]],
		[[{"baseRevision":"zero","operations":[{"op":"tidy","id":"ws"}]}]],
	}
	for _, text in cases do
		local response = router.handleAsync(createRequest("POST", "/api/operations", edits(text)))
		assert.eq(response.status, 400)
	end
	assert.eq(savedText(root), before)
	assert.eq(router.handleAsync(createRequest("GET", "/api/operations")).status, 405)
end)
