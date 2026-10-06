local fs = require("@std/fs")
local json = require("@std/json")
local net = require("@lute/net/server")
local path = require("@std/path")
local test = require("@std/test")

local routes = require("@root/server/routes")
local store = require("@root/store")
local testing = require("@root/testing")

local function request(method: string, route: string, value: json.Object?, workspace: string?): net.ReceivedRequest
	local headers: { [string]: string } = {}
	if workspace then
		headers["x-orion-workspace"] = workspace
	end
	return {
		method = method,
		path = route,
		body = if value then json.serialize(value) else "",
		query = {} :: { [string]: string },
		headers = headers,
	}
end

local function decoded(response): json.Object
	return assert(json.asObject(json.deserialize(response.body) :: json.Value))
end

local function setup(name: string)
	local root = testing.directory(name)
	local status = json.object({ state = "idle" })
	local router
	router = routes.new(root, "default", {
		status = function()
			return status
		end,
		run = function()
			return status
		end,
	}, function() end)
	return root, router
end

test.case("GET reports a missing file and PUT creates it with a guarded revision", function(assert)
	local root, router = setup("routes-missing")
	local missing = router.handle(request("GET", "/api/orion"))
	assert.eq(missing.status, 404)
	assert.eq(decoded(missing).path, store.filePath(root))
	assert.eq(decoded(missing).workspace, "default")
	local change = json.object({ baseRevision = json.null, nodes = {}, links = {} })
	local saved = router.handle(request("PUT", "/api/orion", change))
	assert.eq(saved.status, 200)
	assert.eq(decoded(saved).revision, 0)
	assert.eq(router.handle(request("PUT", "/api/orion", change)).status, 409)
	assert.eq(decoded(router.handle(request("PUT", "/api/orion", change))).revision, 0)
end)

test.case("PUT retains unknown top-level fields and rejects a stale workspace", function(assert)
	local root, router = setup("routes-preserve")
	local doc = testing.doc({}, {})
	doc.raw = json.object({ extra = json.object({ held = true }) })
	store.write(root, doc)
	local change = json.object({ baseRevision = 0, nodes = {}, links = {} })
	assert.eq(router.handle(request("PUT", "/api/orion", change, "other")).status, 409)
	assert.eq(router.handle(request("PUT", "/api/orion", change, "default")).status, 200)
	local updated = decoded(router.handle(request("GET", "/api/orion")))
	assert.eq(updated.revision, 1)
	local extra = json.asObject(updated.extra)
	assert.eq(if extra then extra.held else nil, true)
	assert.eq(#store.backups(root), 1)
end)

test.case("workspace routes create, list, and switch", function(assert)
	local root, router = setup("routes-workspaces")
	local created =
		router.handle(request("POST", "/api/workspaces", json.object({ name = "planning", label = "Planning" })))
	assert.eq(created.status, 201)
	assert.eq(decoded(created).active, "default")
	local createdDoc = store.read(store.workspaceDir(root, "planning"))
	assert.eq(if createdDoc then createdDoc.revision else nil, 0)
	local switched = router.handle(request("POST", "/api/workspaces/active", json.object({ name = "planning" })))
	assert.eq(switched.status, 200)
	assert.eq(decoded(switched).active, "planning")
	assert.eq(decoded(router.handle(request("GET", "/api/workspaces"))).active, "planning")
	assert.eq(
		router.handle(
			request("PUT", "/api/orion", json.object({ baseRevision = 0, nodes = {}, links = {} }), "default")
		).status,
		409
	)
end)

test.case("static route serves files and falls back to index outside the API", function(assert)
	local root, _router = setup("routes-static")
	local folder = tostring(path.join(root, "site"))
	fs.createDirectory(folder, { makeParents = true })
	fs.writeStringToFile(path.join(folder, "index.html"), "home")
	fs.writeStringToFile(path.join(folder, "app.js"), "code")
	local router = routes.new(root, "default", {
		status = function()
			return json.object({ state = "idle" })
		end,
		run = function()
			return json.object({ state = "idle" })
		end,
	}, function() end, folder)
	assert.eq(router.handle(request("GET", "/app.js")).body, "code")
	assert.eq(router.handle(request("GET", "/deep/link")).body, "home")
	assert.eq(router.handle(request("GET", "/api/unknown")).status, 404)
end)
