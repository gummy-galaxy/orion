local fs = require("@std/fs")
local json = require("@std/json")
local net = require("@lute/net/server")
local path = require("@std/path")
local test = require("@std/test")

local insertFile = require("@root/media/insertFile")
local routes = require("@root/server/routes")
local store = require("@root/store")
local testing = require("@root/testing")

local function createRequest(
	method: string,
	route: string,
	value: json.Object?,
	workspace: string?
): net.ReceivedRequest
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

local function decodeResponse(response): json.Object
	return assert(json.asObject(json.deserialize(response.body) :: json.Value))
end

local function createRouter(name: string)
	local root = testing.directory(name)
	local status = json.object({ state = "idle" })
	local router
	router = routes.create(root, "default", {
		getStatus = function()
			return status
		end,

		run = function()
			return status
		end,
	}, function() end)
	return root, router
end

test.case("GET returns migrated document with unknown root data", function(assert)
	local root, router = createRouter("routes-migration")
	fs.createDirectory(root, { makeParents = true })
	fs.writeStringToFile(
		store.filePath(root),
		[[{"version":1,"settings":{"githubOwner":"Vocksel","theme":"dark"},"nodes":[{"id":"a","type":"task","data":{"repo":"orion","pr":12}}],"links":[],"extra":"kept"}]]
	)
	local response = decodeResponse(router.handle(createRequest("GET", "/api/orion")))
	local settings = json.asObject(response.settings)
	local nodes = json.asArray(response.nodes)
	local item = if nodes then json.asObject(nodes[1]) else nil
	local data = if item then json.asObject(item.data) else nil
	assert.eq(response.version, 2)
	assert.eq(response.extra, "kept")
	assert.eq(settings and settings.theme, "dark")
	assert.eq(settings and settings.githubOwner, nil)
	assert.eq(data and data.repo, "Vocksel/orion")
	assert.eq(data and data.pr, nil)
	assert.eq(data and #(json.asArray(data.refs) or {}), 1)
end)

test.case("image routes import and serve workspace-local bytes", function(assert)
	local root, router = createRouter("routes-images")
	store.createWorkspace(root, "ideas")
	local bytes = string.char(137, 80, 78, 71, 13, 10, 26, 10) .. "image bytes"
	local function request(method: string, route: string, workspace: string, body: string?): net.ReceivedRequest
		local req = createRequest(method, route)
		req.query.workspace = workspace
		req.body = body or ""
		return req
	end
	local imported = router.handle(request("POST", "/api/images", "ideas", bytes))
	assert.eq(imported.status, 201)
	local asset = decodeResponse(imported).asset :: string
	assert.eq(type(asset), "string")
	assert.eq(decodeResponse(imported).mime, "image/png")
	local served = router.handle(request("GET", `/api/images/{asset}`, "ideas"))
	assert.eq(served.status, 200)
	assert.eq(served.body, bytes)
	assert.eq(served.headers["content-type"], "image/png")
	assert.eq(router.handle(request("GET", `/api/images/{asset}`, "default")).status, 404)
	assert.eq(router.handle(request("POST", "/api/images", "missing", bytes)).status, 404)
	assert.eq(router.handle(request("POST", "/api/images", "ideas", "not an image")).status, 400)
	assert.eq(router.handle(request("POST", "/api/images", "ideas", string.rep("x", 5 * 1024 * 1024 + 1))).status, 400)
	assert.eq(router.handle(request("GET", "/api/images/../orion.json", "ideas")).status, 400)
	assert.eq(router.handle(request("GET", "/api/images/missing.png", "ideas")).status, 404)
	assert.eq(router.handle(request("POST", `/api/images/{asset}`, "ideas")).status, 405)
	assert.eq(fs.readFileToString(path.join(store.getWorkspaceDir(root, "ideas"), "assets", asset)), bytes)
	local formats = {
		{ bytes = string.char(255, 216, 255) .. "jpeg", mime = "image/jpeg", extension = "jpg" },
		{ bytes = "GIF89a" .. "gif", mime = "image/gif", extension = "gif" },
		{ bytes = "RIFF0000WEBP" .. "webp", mime = "image/webp", extension = "webp" },
	}
	for _, format in formats do
		local response = router.handle(request("POST", "/api/images", "ideas", format.bytes))
		assert.eq(response.status, 201)
		local name = decodeResponse(response).asset :: string
		assert.eq(name:sub(-#format.extension - 1), `.{format.extension}`)
		assert.eq(decodeResponse(response).mime, format.mime)
		assert.eq(router.handle(request("GET", `/api/images/{name}`, "ideas")).body, format.bytes)
	end
	local source = path.join(root, "from-cli.png")
	fs.writeStringToFile(source, bytes)
	local cliItem = insertFile(store.getWorkspaceDir(root, "ideas"), "ideas", tostring(source), "From CLI")
	local cliAsset = cliItem.data.asset :: string
	assert.eq(router.handle(request("GET", `/api/images/{cliAsset}`, "ideas")).body, bytes)
end)

test.case("GET reports a missing file and PUT creates it with a guarded revision", function(assert)
	local root, router = createRouter("routes-missing")
	local missing = router.handle(createRequest("GET", "/api/orion"))
	assert.eq(missing.status, 404)
	assert.eq(decodeResponse(missing).path, store.filePath(root))
	assert.eq(decodeResponse(missing).workspace, "default")
	local change = json.object({ baseRevision = json.null, nodes = {}, links = {} })
	local saved = router.handle(createRequest("PUT", "/api/orion", change))
	assert.eq(saved.status, 200)
	assert.eq(decodeResponse(saved).revision, 0)
	assert.eq(router.handle(createRequest("PUT", "/api/orion", change)).status, 409)
	assert.eq(decodeResponse(router.handle(createRequest("PUT", "/api/orion", change))).revision, 0)
end)

test.case("PUT retains unknown top-level fields and rejects a stale workspace", function(assert)
	local root, router = createRouter("routes-preserve")
	local doc = testing.createDoc({}, {})
	doc.raw = json.object({ extra = json.object({ held = true }) })
	store.write(root, doc)
	local change = json.object({ baseRevision = 0, nodes = {}, links = {} })
	assert.eq(router.handle(createRequest("PUT", "/api/orion", change, "other")).status, 409)
	assert.eq(router.handle(createRequest("PUT", "/api/orion", change, "default")).status, 200)
	local updated = decodeResponse(router.handle(createRequest("GET", "/api/orion")))
	assert.eq(updated.revision, 1)
	local extra = json.asObject(updated.extra)
	assert.eq(if extra then extra.held else nil, true)
	assert.eq(#store.getBackups(root), 1)
end)

test.case("PUT saves stickers when present and preserves them when omitted", function(assert)
	local root, router = createRouter("routes-stickers")
	store.write(root, testing.createDoc({}, {}))
	local stickers: json.Array = { json.object({ id = "one", emoji = "⭐" }) }
	local loadout: json.Array = { "one", json.null }
	local first =
		json.object({ baseRevision = 0, nodes = {}, links = {}, stickers = stickers, stickerLoadout = loadout })
	assert.eq(router.handle(createRequest("PUT", "/api/orion", first)).status, 200)
	local saved = decodeResponse(router.handle(createRequest("GET", "/api/orion")))
	assert.eq(#(json.asArray(saved.stickers) or {}), 1)
	assert.eq(#(json.asArray(saved.stickerLoadout) or {}), 2)
	assert.eq(
		router.handle(createRequest("PUT", "/api/orion", json.object({ baseRevision = 1, nodes = {}, links = {} }))).status,
		200
	)
	local preserved = decodeResponse(router.handle(createRequest("GET", "/api/orion")))
	assert.eq(#(json.asArray(preserved.stickers) or {}), 1)
	assert.eq(#(json.asArray(preserved.stickerLoadout) or {}), 2)
	assert.eq(
		router.handle(
			createRequest(
				"PUT",
				"/api/orion",
				json.object({ baseRevision = 2, nodes = {}, links = {}, stickers = {}, stickerLoadout = {} })
			)
		).status,
		200
	)
	local cleared = decodeResponse(router.handle(createRequest("GET", "/api/orion")))
	assert.eq(#(json.asArray(cleared.stickers) or {}), 0)
	assert.eq(#(json.asArray(cleared.stickerLoadout) or {}), 0)
end)

test.case("focus reports use the workspace and tab without changing the document", function(assert)
	local root, router = createRouter("routes-focus")
	store.write(root, testing.createDoc({}, {}))
	store.createWorkspace(root, "other")
	local other = store.getWorkspaceDir(root, "other")
	local focusFile = tostring(path.join(root, "focus.json"))
	assert.eq(
		router.handle(
			createRequest(
				"POST",
				"/api/focus",
				json.object({ tab = "a", workspace = "missing", open = json.null, selected = {} })
			)
		).status,
		404
	)
	assert.eq(
		router.handle(
			createRequest(
				"POST",
				"/api/focus",
				json.object({ tab = "a", workspace = "other", open = json.null, selected = {} })
			)
		).status,
		409
	)
	assert.eq(
		router.handle(
			createRequest(
				"POST",
				"/api/focus",
				json.object({ tab = "a", workspace = "default", open = "group", selected = { "card" } })
			)
		).status,
		200
	)
	local focus = json.asObject(json.deserialize(fs.readFileToString(focusFile)) :: json.Value)
	if not focus then
		error("missing focus report")
	end
	assert.eq(focus.tab, "a")
	assert.eq(focus.open, "group")
	assert.eq(#(json.asArray(focus.selected) or {}), 1)
	assert.eq(type(focus.updatedAt), "string")
	assert.eq(
		router.handle(
			createRequest("POST", "/api/focus", json.object({ tab = "b", workspace = "default", closed = true }))
		).status,
		200
	)
	assert.eq(fs.exists(focusFile), true)
	assert.eq(
		router.handle(
			createRequest("POST", "/api/focus", json.object({ tab = "a", workspace = "default", closed = true }))
		).status,
		200
	)
	assert.eq(fs.exists(focusFile), false)
	assert.eq(
		router.handle(
			createRequest(
				"POST",
				"/api/focus",
				json.object({ tab = "a", workspace = "default", open = json.null, selected = {} })
			)
		).status,
		200
	)
	router.switchTo("other")
	assert.eq(fs.exists(focusFile), false)
	assert.eq(fs.exists(path.join(other, "focus.json")), false)
	local doc = store.read(root)
	assert.eq(if doc then doc.revision else nil, 0)
	assert.eq(#store.getBackups(root), 0)
end)

test.case("workspace routes create, list, and switch", function(assert)
	local root, router = createRouter("routes-workspaces")
	local created =
		router.handle(createRequest("POST", "/api/workspaces", json.object({ name = "planning", label = "Planning" })))
	assert.eq(created.status, 201)
	assert.eq(decodeResponse(created).active, "default")
	local createdDoc = store.read(store.getWorkspaceDir(root, "planning"))
	assert.eq(if createdDoc then createdDoc.revision else nil, 0)
	local switched = router.handle(createRequest("POST", "/api/workspaces/active", json.object({ name = "planning" })))
	assert.eq(switched.status, 200)
	assert.eq(decodeResponse(switched).active, "planning")
	assert.eq(decodeResponse(router.handle(createRequest("GET", "/api/workspaces"))).active, "planning")
	assert.eq(
		router.handle(
			createRequest("PUT", "/api/orion", json.object({ baseRevision = 0, nodes = {}, links = {} }), "default")
		).status,
		409
	)
end)

test.case("GET reads the workspace a request names", function(assert)
	local root, router = createRouter("routes-requested")
	store.createWorkspace(root, "planning", "Planning")
	local planning = router.handle(createRequest("GET", "/api/orion", nil, "planning"))
	assert.eq(planning.status, 200)
	assert.eq(decodeResponse(planning).revision, 0)
	local missing = router.handle(createRequest("GET", "/api/orion", nil, "default"))
	assert.eq(missing.status, 404)
	assert.eq(decodeResponse(missing).workspace, "default")
	assert.eq(router.handle(createRequest("GET", "/api/orion", nil, "unknown")).status, 404)
	assert.eq(router.getActive(), "default")
end)

test.case("static route serves files and falls back to index outside the API", function(assert)
	local root, _router = createRouter("routes-static")
	local folder = tostring(path.join(root, "site"))
	fs.createDirectory(folder, { makeParents = true })
	fs.writeStringToFile(path.join(folder, "index.html"), "home")
	fs.writeStringToFile(path.join(folder, "app.js"), "code")
	local router = routes.create(root, "default", {
		getStatus = function()
			return json.object({ state = "idle" })
		end,

		run = function()
			return json.object({ state = "idle" })
		end,
	}, function() end, folder)
	assert.eq(router.handle(createRequest("GET", "/app.js")).body, "code")
	assert.eq(router.handle(createRequest("GET", "/deep/link")).body, "home")
	assert.eq(router.handle(createRequest("GET", "/api/unknown")).status, 404)
end)

test.case("settings routes merge preferences beside the workspaces", function(assert)
	local root, router = createRouter("routes-settings")
	assert.eq(router.handle(createRequest("GET", "/api/settings")).body, "{}")

	local saved =
		router.handle(createRequest("POST", "/api/settings", json.object({ theme = "vibrant", sidebar = false })))
	assert.eq(saved.status, 200)

	router.handle(createRequest("POST", "/api/settings", json.object({ colorMode = "dark", sidebar = json.null })))
	local settings = decodeResponse(router.handle(createRequest("GET", "/api/settings")))
	assert.eq(settings.theme, "vibrant")
	assert.eq(settings.colorMode, "dark")
	assert.eq(settings.sidebar, nil)
	assert.eq(fs.exists(path.join(root, "settings.json")), true)

	fs.writeStringToFile(path.join(root, "settings.json"), "not json")
	assert.eq(router.handle(createRequest("GET", "/api/settings")).body, "{}")

	local invalid = createRequest("POST", "/api/settings")
	invalid.body = "[1]"
	assert.eq(router.handle(invalid).status, 400)
	invalid.body = json.serialize(json.object({ big = string.rep("x", 64 * 1024) }))
	assert.eq(router.handle(invalid).status, 400)
	assert.eq(router.handle(createRequest("DELETE", "/api/settings")).status, 405)
end)

test.case("PUT /api/orion/style sets and clears the canvas cover and bumps the revision like a save", function(assert)
	local root, router = createRouter("routes-canvas-style")
	store.write(root, testing.createDoc({ testing.group("ws", "Workspace", nil) }))
	fs.createDirectory(path.join(root, "assets"), { makeParents = true })
	fs.writeStringToFile(path.join(root, "assets", "image-logo.png"), "bytes")
	local set = router.handle(
		createRequest("PUT", "/api/orion/style", json.object({ cover = "image-logo.png", background = "#1d1b2e" }))
	)
	assert.eq(set.status, 200)
	assert.eq(store.load(root).settings.cover, "image-logo.png")
	assert.eq(store.load(root).settings.background, "#1d1b2e")
	assert.eq(store.load(root).revision, 1)
	-- A window that read the file before the style change has a stale revision, so its save is refused and it reloads.
	local stale = json.object({ baseRevision = 0, nodes = {}, links = {} })
	assert.eq(router.handle(createRequest("PUT", "/api/orion", stale)).status, 409)
	local cleared = router.handle(createRequest("PUT", "/api/orion/style", json.object({ cover = json.null })))
	assert.eq(cleared.status, 200)
	assert.eq(store.load(root).settings.cover, nil)
	assert.eq(store.load(root).settings.background, "#1d1b2e")
	assert.eq(store.load(root).revision, 2)
	assert.eq(
		router.handle(createRequest("PUT", "/api/orion/style", json.object({ cover = "image-missing.png" }))).status,
		400
	)
	assert.eq(store.load(root).revision, 2)
	assert.eq(router.handle(createRequest("GET", "/api/orion/style")).status, 405)
	assert.eq(
		router.handle(createRequest("PUT", "/api/orion/style", json.object({ cover = "x" }), "ideas")).status,
		409
	)
end)
