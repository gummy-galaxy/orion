local fs = require("@std/fs")
local json = require("@std/json")
local net = require("@lute/net/server")
local path = require("@std/path")
local test = require("@std/test")

local appendLog = require("@root/log/appendLog")
local createWorkspace = require("@root/store/createWorkspace")
local getBackups = require("@root/store/getBackups")
local getDocPath = require("@root/store/getDocPath")
local getWorkspaceDir = require("@root/store/getWorkspaceDir")
local insertFile = require("@root/media/insertFile")
local loadDoc = require("@root/store/loadDoc")
local readDoc = require("@root/store/readDoc")
local routes = require("@root/server/routes")
local testing = require("@root/testing")
local writeDoc = require("@root/store/writeDoc")

local function createRequest(
	method: string,
	route: string,
	value: json.Object?,
	workspace: string?
): net.ReceivedRequest
	local headers: { [string]: string } = {}

	if workspace then
		headers["x-orion-canvas"] = workspace
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

		runAsync = function()
			return status
		end,
	}, function() end)
	return root, router
end

-- One addCard edit for a card with `id`, as the app sends it.
local function createOperation(id: string): json.Object
	return json.object({
		op = "addCard",
		id = id,
		x = 0,
		y = 0,
		data = json.object({ kind = "task", label = id, itemKind = "step", status = "todo" }),
	})
end

test.case("GET returns the document with unknown root data", function(assert)
	local root, router = createRouter("routes-unknown-data")
	fs.createDirectory(root, { makeParents = true })
	testing.writeCanvasText(
		root,
		[[{"version":2,"settings":{"githubOwner":"Vocksel","theme":"dark"},"nodes":[{"id":"a","type":"task","data":{"repo":"Vocksel/orion","refs":[{"source":"github","kind":"pull","key":"Vocksel/orion#12"}]}}],"links":[],"extra":"kept"}]]
	)
	local response = decodeResponse(router.handleAsync(createRequest("GET", "/api/orion")))
	local settings = json.asObject(response.settings)
	local nodes = json.asArray(response.nodes)
	local item = if nodes then json.asObject(nodes[1]) else nil
	local data = if item then json.asObject(item.data) else nil
	assert.eq(response.version, 2)
	assert.eq(response.extra, "kept")
	assert.eq(settings and settings.theme, "dark")
	assert.eq(settings and settings.githubOwner, nil)
	assert.eq(data and data.repo, "Vocksel/orion")
	assert.eq(data and #(json.asArray(data.refs) or {}), 1)
end)

test.case("GET sends derived values beside the document without storing them", function(assert)
	local root, router = createRouter("routes-derived")
	fs.createDirectory(root, { makeParents = true })
	testing.writeCanvasText(
		root,
		[[{"version":2,"revision":3,"settings":{"sources":[]},"nodes":[{"id":"a","type":"task","position":{"x":0,"y":0},"data":{"kind":"task","label":"A","itemKind":"step","status":"todo"}},{"id":"b","type":"task","position":{"x":0,"y":0},"data":{"kind":"task","label":"B","itemKind":"step","status":"todo"}}],"links":[{"id":"a>b","from":"a","to":"b","kind":"blocks"}]}]]
	)
	local response = decodeResponse(router.handleAsync(createRequest("GET", "/api/orion")))
	local derived = json.asObject(response.derived) :: json.Object
	local status = json.asObject(derived.status) :: json.Object
	local leverage = json.asObject(derived.leverage) :: json.Object
	assert.eq(status.a, "ready")
	assert.eq(status.b, "blocked")
	assert.eq(leverage.a, 1)
	assert.eq(response.revision, 3)
	assert.eq(testing.readCanvasText(root):find("derived"), nil)
end)

test.case("image routes import and serve workspace-local bytes", function(assert)
	local root, router = createRouter("routes-images")
	createWorkspace(root, "ideas")
	local bytes = string.char(137, 80, 78, 71, 13, 10, 26, 10) .. "image bytes"
	local function request(method: string, route: string, workspace: string, body: string?): net.ReceivedRequest
		local req = createRequest(method, route)
		req.query.canvas = workspace
		req.body = body or ""
		return req
	end
	local imported = router.handleAsync(request("POST", "/api/images", "ideas", bytes))
	assert.eq(imported.status, 201)
	local asset = decodeResponse(imported).asset :: string
	assert.eq(type(asset), "string")
	assert.eq(decodeResponse(imported).mime, "image/png")
	local served = router.handleAsync(request("GET", `/api/images/{asset}`, "ideas"))
	assert.eq(served.status, 200)
	assert.eq(served.body, bytes)
	assert.eq(served.headers["content-type"], "image/png")
	assert.eq(router.handleAsync(request("GET", `/api/images/{asset}`, "default")).status, 404)
	assert.eq(router.handleAsync(request("POST", "/api/images", "missing", bytes)).status, 404)
	assert.eq(router.handleAsync(request("POST", "/api/images", "ideas", "not an image")).status, 400)
	assert.eq(
		router.handleAsync(request("POST", "/api/images", "ideas", string.rep("x", 5 * 1024 * 1024 + 1))).status,
		400
	)
	assert.eq(router.handleAsync(request("GET", "/api/images/../orion.json", "ideas")).status, 400)
	assert.eq(router.handleAsync(request("GET", "/api/images/missing.png", "ideas")).status, 404)
	assert.eq(router.handleAsync(request("POST", `/api/images/{asset}`, "ideas")).status, 405)
	assert.eq(fs.readFileToString(path.join(getWorkspaceDir(root, "ideas"), "assets", asset)), bytes)
	local formats = {
		{ bytes = string.char(255, 216, 255) .. "jpeg", mime = "image/jpeg", extension = "jpg" },
		{ bytes = "GIF89a" .. "gif", mime = "image/gif", extension = "gif" },
		{ bytes = "RIFF0000WEBP" .. "webp", mime = "image/webp", extension = "webp" },
	}
	for _, format in formats do
		local response = router.handleAsync(request("POST", "/api/images", "ideas", format.bytes))
		assert.eq(response.status, 201)
		local name = decodeResponse(response).asset :: string
		assert.eq(name:sub(-#format.extension - 1), `.{format.extension}`)
		assert.eq(decodeResponse(response).mime, format.mime)
		assert.eq(router.handleAsync(request("GET", `/api/images/{name}`, "ideas")).body, format.bytes)
	end
	local source = path.join(root, "from-cli.png")
	fs.writeStringToFile(source, bytes)
	local cliItem = insertFile(getWorkspaceDir(root, "ideas"), "ideas", tostring(source), "From CLI")
	local cliAsset = cliItem.data.asset :: string
	assert.eq(router.handleAsync(request("GET", `/api/images/{cliAsset}`, "ideas")).body, bytes)
end)

test.case("GET reports a missing file and an operation list creates it, guarded by its revision", function(assert)
	local root, router = createRouter("routes-missing")
	local missing = router.handleAsync(createRequest("GET", "/api/orion"))
	assert.eq(missing.status, 404)
	assert.eq(decodeResponse(missing).path, getDocPath(root))
	assert.eq(decodeResponse(missing).canvas, "default")
	local saved = router.handleAsync(
		createRequest(
			"POST",
			"/api/operations",
			json.object({ baseRevision = json.null, operations = { createOperation("a") } })
		)
	)
	assert.eq(saved.status, 200)
	assert.eq(decodeResponse(saved).revision, 1)
	local stale = json.object({ baseRevision = 0, operations = { createOperation("b") } })
	assert.eq(router.handleAsync(createRequest("POST", "/api/operations", stale)).status, 409)
	assert.eq(decodeResponse(router.handleAsync(createRequest("GET", "/api/orion"))).revision, 1)
end)

test.case("an operation list retains unknown top-level fields and rejects a stale workspace", function(assert)
	local root, router = createRouter("routes-preserve")
	local doc = testing.createDoc({}, {})
	doc.raw = json.object({ extra = json.object({ held = true }) })
	writeDoc(root, doc)
	local change = json.object({ baseRevision = 0, operations = { createOperation("a") } })
	assert.eq(router.handleAsync(createRequest("POST", "/api/operations", change, "other")).status, 409)
	assert.eq(router.handleAsync(createRequest("POST", "/api/operations", change, "default")).status, 200)
	local updated = decodeResponse(router.handleAsync(createRequest("GET", "/api/orion")))
	assert.eq(updated.revision, 1)
	local extra = json.asObject(updated.extra)
	assert.eq(if extra then extra.held else nil, true)
end)

test.case("sticker operations save stickers, and other edits leave them alone", function(assert)
	local root, router = createRouter("routes-stickers")
	writeDoc(root, testing.createDoc({}, {}))
	local stickers: json.Array = { json.object({ id = "one", emoji = "⭐" }) }
	local loadout: json.Array = { "one", json.null }
	local first = json.object({
		baseRevision = 0,
		operations = {
			json.object({ op = "setStickers", stickers = stickers }),
			json.object({ op = "setStickerLoadout", stickerLoadout = loadout }),
		},
	})
	assert.eq(router.handleAsync(createRequest("POST", "/api/operations", first)).status, 200)
	local saved = decodeResponse(router.handleAsync(createRequest("GET", "/api/orion")))
	assert.eq(#(json.asArray(saved.stickers) or {}), 1)
	assert.eq(#(json.asArray(saved.stickerLoadout) or {}), 2)
	local other = json.object({ baseRevision = 1, operations = { createOperation("a") } })
	assert.eq(router.handleAsync(createRequest("POST", "/api/operations", other)).status, 200)
	local preserved = decodeResponse(router.handleAsync(createRequest("GET", "/api/orion")))
	assert.eq(#(json.asArray(preserved.stickers) or {}), 1)
	assert.eq(#(json.asArray(preserved.stickerLoadout) or {}), 2)
	local cleared = json.object({
		baseRevision = 2,
		operations = {
			json.object({ op = "setStickers", stickers = {} }),
			json.object({ op = "setStickerLoadout", stickerLoadout = {} }),
		},
	})
	assert.eq(router.handleAsync(createRequest("POST", "/api/operations", cleared)).status, 200)
	local empty = decodeResponse(router.handleAsync(createRequest("GET", "/api/orion")))
	assert.eq(#(json.asArray(empty.stickers) or {}), 0)
	assert.eq(#(json.asArray(empty.stickerLoadout) or {}), 0)
end)

test.case("focus reports use the workspace and tab without changing the document", function(assert)
	local root, router = createRouter("routes-focus")
	writeDoc(root, testing.createDoc({}, {}))
	createWorkspace(root, "other")
	local other = getWorkspaceDir(root, "other")
	local focusFile = tostring(path.join(root, "focus.json"))
	assert.eq(
		router.handleAsync(
			createRequest(
				"POST",
				"/api/focus",
				json.object({ tab = "a", canvas = "missing", open = json.null, selected = {} })
			)
		).status,
		404
	)
	assert.eq(
		router.handleAsync(
			createRequest(
				"POST",
				"/api/focus",
				json.object({ tab = "a", canvas = "other", open = json.null, selected = {} })
			)
		).status,
		409
	)
	assert.eq(
		router.handleAsync(
			createRequest(
				"POST",
				"/api/focus",
				json.object({ tab = "a", canvas = "default", open = "group", selected = { "card" } })
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
		router.handleAsync(
			createRequest("POST", "/api/focus", json.object({ tab = "b", canvas = "default", closed = true }))
		).status,
		200
	)
	assert.eq(fs.exists(focusFile), true)
	assert.eq(
		router.handleAsync(
			createRequest("POST", "/api/focus", json.object({ tab = "a", canvas = "default", closed = true }))
		).status,
		200
	)
	assert.eq(fs.exists(focusFile), false)
	assert.eq(
		router.handleAsync(
			createRequest(
				"POST",
				"/api/focus",
				json.object({ tab = "a", canvas = "default", open = json.null, selected = {} })
			)
		).status,
		200
	)
	router.switchTo("other")
	assert.eq(fs.exists(focusFile), false)
	assert.eq(fs.exists(path.join(other, "focus.json")), false)
	local doc = readDoc(root)
	assert.eq(if doc then doc.revision else nil, 0)
	assert.eq(#getBackups(root), 0)
end)

test.case("workspace routes create, list, and switch", function(assert)
	local root, router = createRouter("routes-workspaces")
	local created = router.handleAsync(
		createRequest("POST", "/api/canvases", json.object({ name = "planning", label = "Planning" }))
	)
	assert.eq(created.status, 201)
	assert.eq(decodeResponse(created).active, "default")
	local createdDoc = readDoc(getWorkspaceDir(root, "planning"))
	assert.eq(if createdDoc then createdDoc.revision else nil, 0)
	local switched =
		router.handleAsync(createRequest("POST", "/api/canvases/active", json.object({ name = "planning" })))
	assert.eq(switched.status, 200)
	assert.eq(decodeResponse(switched).active, "planning")
	assert.eq(decodeResponse(router.handleAsync(createRequest("GET", "/api/canvases"))).active, "planning")
	assert.eq(
		router.handleAsync(
			createRequest(
				"POST",
				"/api/operations",
				json.object({ baseRevision = 0, operations = { createOperation("late") } }),
				"default"
			)
		).status,
		409
	)
end)

test.case("GET reads the workspace a request names", function(assert)
	local root, router = createRouter("routes-requested")
	createWorkspace(root, "planning", "Planning")
	local planning = router.handleAsync(createRequest("GET", "/api/orion", nil, "planning"))
	assert.eq(planning.status, 200)
	assert.eq(decodeResponse(planning).revision, 0)
	local missing = router.handleAsync(createRequest("GET", "/api/orion", nil, "default"))
	assert.eq(missing.status, 404)
	assert.eq(decodeResponse(missing).canvas, "default")
	assert.eq(router.handleAsync(createRequest("GET", "/api/orion", nil, "unknown")).status, 404)
	assert.eq(router.getActive(), "default")
end)

test.case("GET /api/log returns the entries of the canvas it names, oldest first", function(assert)
	local root, router = createRouter("routes-log")
	createWorkspace(root, "planning", "Planning")
	appendLog(getWorkspaceDir(root, "planning"), function()
		return {
			id = "log-1",
			text = "Planned",
			time = "2026-10-12T18:00:00Z",
			author = { kind = "person", name = "marin" },
			targets = {},
		}
	end)

	local request = createRequest("GET", "/api/log")
	request.query = { canvas = "planning" }
	local response = router.handleAsync(request)
	assert.eq(response.status, 200)
	local entries = json.asArray(decodeResponse(response).entries) :: json.Array
	assert.eq(#entries, 1)
	assert.eq((json.asObject(entries[1]) :: json.Object).text, "Planned")

	local empty = createRequest("GET", "/api/log")
	empty.query = { canvas = "default" }
	local emptyEntries = json.asArray(decodeResponse(router.handleAsync(empty)).entries) :: json.Array
	assert.eq(#emptyEntries, 0)
	assert.eq(router.handleAsync(createRequest("POST", "/api/log")).status, 405)
	local unknown = createRequest("GET", "/api/log")
	unknown.query = { canvas = "unknown" }
	assert.eq(router.handleAsync(unknown).status, 404)
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

		runAsync = function()
			return json.object({ state = "idle" })
		end,
	}, function() end, folder)
	local script = router.handleAsync(createRequest("GET", "/app.js"))
	assert.eq(script.body, "code")
	assert.eq(script.headers["content-security-policy"], nil)
	local page = createRequest("GET", "/deep/link")
	page.headers.host = "127.0.0.1:5198"
	local served = router.handleAsync(page)
	assert.eq(served.body, "home")
	local policy = served.headers["content-security-policy"]
	assert.neq(policy:find("script-src 'self';", 1, true), nil)
	assert.neq(policy:find("ws://127.0.0.1:5198", 1, true), nil)
	assert.neq(policy:find("frame-ancestors 'none'", 1, true), nil)
	assert.eq(router.handleAsync(createRequest("GET", "/api/unknown")).status, 404)
end)

test.case("settings routes merge preferences beside the workspaces", function(assert)
	local root, router = createRouter("routes-settings")
	assert.eq(router.handleAsync(createRequest("GET", "/api/settings")).body, "{}")

	local saved =
		router.handleAsync(createRequest("POST", "/api/settings", json.object({ theme = "vibrant", sidebar = false })))
	assert.eq(saved.status, 200)

	router.handleAsync(createRequest("POST", "/api/settings", json.object({ colorMode = "dark", sidebar = json.null })))
	local settings = decodeResponse(router.handleAsync(createRequest("GET", "/api/settings")))
	assert.eq(settings.theme, "vibrant")
	assert.eq(settings.colorMode, "dark")
	assert.eq(settings.sidebar, nil)
	assert.eq(fs.exists(path.join(root, "settings.json")), true)

	fs.writeStringToFile(path.join(root, "settings.json"), "not json")
	assert.eq(router.handleAsync(createRequest("GET", "/api/settings")).body, "{}")

	local invalid = createRequest("POST", "/api/settings")
	invalid.body = "[1]"
	assert.eq(router.handleAsync(invalid).status, 400)
	invalid.body = json.serialize(json.object({ big = string.rep("x", 64 * 1024) }))
	assert.eq(router.handleAsync(invalid).status, 400)
	assert.eq(router.handleAsync(createRequest("DELETE", "/api/settings")).status, 405)
end)

test.case("PUT /api/orion/style sets and clears the canvas cover and bumps the revision like a save", function(assert)
	local root, router = createRouter("routes-canvas-style")
	writeDoc(root, testing.createDoc({ testing.group("ws", "Workspace", nil) }))
	fs.createDirectory(path.join(root, "assets"), { makeParents = true })
	fs.writeStringToFile(path.join(root, "assets", "image-logo.png"), "bytes")
	local set = router.handleAsync(
		createRequest("PUT", "/api/orion/style", json.object({ cover = "image-logo.png", background = "#1d1b2e" }))
	)
	assert.eq(set.status, 200)
	assert.eq(loadDoc(root).settings.cover, "image-logo.png")
	assert.eq(loadDoc(root).settings.background, "#1d1b2e")
	assert.eq(loadDoc(root).revision, 1)
	-- A window that read the file before the style change has a stale revision, so its save is refused and it reloads.
	local stale = json.object({ baseRevision = 0, operations = { createOperation("late") } })
	assert.eq(router.handleAsync(createRequest("POST", "/api/operations", stale)).status, 409)
	local cleared = router.handleAsync(createRequest("PUT", "/api/orion/style", json.object({ cover = json.null })))
	assert.eq(cleared.status, 200)
	assert.eq(loadDoc(root).settings.cover, nil)
	assert.eq(loadDoc(root).settings.background, "#1d1b2e")
	assert.eq(loadDoc(root).revision, 2)
	assert.eq(
		router.handleAsync(createRequest("PUT", "/api/orion/style", json.object({ cover = "image-missing.png" }))).status,
		400
	)
	assert.eq(loadDoc(root).revision, 2)
	assert.eq(router.handleAsync(createRequest("GET", "/api/orion/style")).status, 405)
	assert.eq(
		router.handleAsync(createRequest("PUT", "/api/orion/style", json.object({ cover = "x" }), "ideas")).status,
		409
	)
end)

test.case("PUT /api/orion/check-snoozes snoozes and unsnoozes a job and bumps the revision", function(assert)
	local root, router = createRouter("routes-check-snoozes")
	writeDoc(root, testing.createDoc({}))
	local snoozed = router.handleAsync(createRequest(
		"PUT",
		"/api/orion/check-snoozes",
		json.object({
			repo = "vocksel/orion",
			name = "docs",
			snoozed = true,
			["until"] = "2099-01-01T00:00:00.000Z",
		})
	))
	assert.eq(snoozed.status, 200)
	local snoozes = loadDoc(root).settings.checkSnoozes
	assert.eq(#snoozes, 1)
	assert.eq(snoozes[1].untilTime, "2099-01-01T00:00:00Z")
	assert.eq(loadDoc(root).revision, 1)

	local unsnoozed = router.handleAsync(
		createRequest(
			"PUT",
			"/api/orion/check-snoozes",
			json.object({ repo = "vocksel/orion", name = "docs", snoozed = false })
		)
	)
	assert.eq(unsnoozed.status, 200)
	assert.eq(#loadDoc(root).settings.checkSnoozes, 0)
	assert.eq(
		router.handleAsync(createRequest("PUT", "/api/orion/check-snoozes", json.object({ repo = "vocksel/orion" }))).status,
		400
	)
	assert.eq(router.handleAsync(createRequest("GET", "/api/orion/check-snoozes")).status, 405)
end)

test.case("the theme list route serves theme files from the data folder", function(assert)
	local root, router = createRouter("routes-theme-files")
	local folder = path.join(root, "themes")
	fs.createDirectory(folder, { makeParents = true })
	fs.writeStringToFile(path.join(folder, "dusk.json"), '{"name":"Dusk"}')

	local response = router.handleAsync(createRequest("GET", "/api/themes"))
	assert.eq(response.status, 200)
	local entries = json.asArray(decodeResponse(response).themes) :: json.Array
	assert.eq((json.asObject(entries[1]) :: json.Object).file, "dusk.json")
	assert.eq(router.handleAsync(createRequest("POST", "/api/themes")).status, 405)
end)

local function createRevealRouter(name: string, openClients: number)
	local root = testing.directory(name)
	local published: { { name: string, data: json.Object } } = {}
	local hub = {
		count = function()
			return openClients
		end,

		publish = function(eventName: string, data: json.Object)
			table.insert(published, { name = eventName, data = data })
		end,
	}
	local router = routes.create(root, "default", {
		getStatus = function()
			return json.object({ state = "idle" })
		end,

		runAsync = function()
			return json.object({ state = "idle" })
		end,
	}, function() end, nil, hub)
	writeDoc(getWorkspaceDir(root, "default"), testing.createDoc({ testing.task("ci", "Ship it", "todo") }))
	return root, router, published
end

test.case("reveal needs a known canvas and items on it, and an open app", function(assert)
	local _, router = createRevealRouter("routes-reveal-checks", 0)
	local ids = json.object({ canvas = "default", ids = { "ci" } })
	assert.eq(router.handleAsync(createRequest("POST", "/api/reveal", ids)).status, 409)
	assert.eq(
		router.handleAsync(createRequest("POST", "/api/reveal", json.object({ canvas = "default", ids = { "gone" } }))).status,
		404
	)
	assert.eq(
		router.handleAsync(createRequest("POST", "/api/reveal", json.object({ canvas = "nope", ids = { "ci" } }))).status,
		404
	)
	assert.eq(router.handleAsync(createRequest("GET", "/api/reveal")).status, 405)
	assert.eq(router.getActive(), "default")
end)

test.case("reveal publishes to the open app and switches to the item's canvas", function(assert)
	local root, router, published = createRevealRouter("routes-reveal-switch", 1)
	createWorkspace(root, "planning", "Planning")
	writeDoc(getWorkspaceDir(root, "planning"), testing.createDoc({ testing.group("plan", "Plan") }))
	local response = router.handleAsync(
		createRequest("POST", "/api/reveal", json.object({ canvas = "planning", ids = { "plan" }, selectOnly = true }))
	)
	assert.eq(response.status, 200)
	assert.eq(router.getActive(), "planning")
	assert.eq(#published, 1)
	assert.eq(published[1].name, "orion:reveal")
	assert.eq(published[1].data.canvas, "planning")
	assert.eq(published[1].data.selectOnly, true)
	assert.eq(decodeResponse(response).canvas, "planning")
end)
