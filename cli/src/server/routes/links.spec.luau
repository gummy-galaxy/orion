local json = require("@std/json")
local net = require("@lute/net/server")
local test = require("@std/test")

local links = require("@root/server/routes/links")
local store = require("@root/store")
local testing = require("@root/testing")
local types = require("@root/types")

local PULL_URL = "https://github.com/Roblox/foundation/pull/2376"

local function request(method: string, workspace: string?, body: json.Object?): net.ReceivedRequest
	return {
		method = method,
		path = "/api/links",
		body = if body then json.serialize(body) else "",
		query = { canvas = workspace } :: { [string]: string },
		headers = {},
	}
end

local function decode(response): json.Object
	return assert(json.asObject(json.deserialize(response.body) :: json.Value))
end

local function githubRunner(): types.CommandResult
	return testing.result(
		true,
		`\{"data": \{"p1": \{"pullRequest": \{"title": "Add a Chip component", "url": "{PULL_URL}"}}}}`
	)
end

local function createRoot(name: string, nodes: { types.Item }): string
	local root = testing.directory(name)
	store.createWorkspace(root, "ideas")
	store.write(store.getWorkspaceDir(root, "ideas"), testing.createDoc(nodes))
	return root
end

test.case("links route returns a new card's data without saving it", function(assert)
	local root = createRoot("links-found", {})

	local response = links.handle(request("POST", "ideas", json.object({ url = PULL_URL })), root, githubRunner)
	local body = decode(response)
	local data = json.asObject(body.data) :: json.Object

	assert.eq(response.status, 200)
	assert.eq(body.status, "found")
	assert.eq(data.label, "Add a Chip component")
	assert.eq(data.itemKind, "pr")
	assert.eq(#store.load(store.getWorkspaceDir(root, "ideas")).nodes, 0)
end)

test.case("links route points at the card that already tracks the link", function(assert)
	local root = createRoot("links-existing", {
		testing.task("kept", "Chip component", "todo", nil, {
			refs = { { source = "github", kind = "pull", key = "Roblox/foundation#2376", url = PULL_URL } },
		}),
	})

	local body = decode(links.handle(request("POST", "ideas", json.object({ url = PULL_URL })), root, githubRunner))

	assert.eq(body.status, "existing")
	assert.eq(body.id, "kept")
	assert.eq(body.label, "Chip component")
end)

test.case("links route rejects bad requests and reports links it can't use", function(assert)
	local root = createRoot("links-errors", {})

	assert.eq(links.handle(request("GET", "ideas"), root, githubRunner).status, 405)
	assert.eq(links.handle(request("POST", "missing", json.object({ url = PULL_URL })), root, githubRunner).status, 404)
	assert.eq(
		links.handle(request("POST", "ideas", json.object({ url = "not a url" })), root, githubRunner).status,
		400
	)

	local unknown =
		links.handle(request("POST", "ideas", json.object({ url = "https://example.com/page" })), root, githubRunner)
	assert.eq(unknown.status, 422)
	assert.strContains(decode(unknown).error :: string, "no source recognizes")
end)

return {}
