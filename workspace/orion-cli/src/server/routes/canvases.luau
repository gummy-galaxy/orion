local json = require("@std/json")
local net = require("@lute/net/server")

local createWorkspace = require("@root/storage/canvases/createWorkspace")
local getStringField = require("@root/common/getStringField")
local getWorkspaces = require("@root/storage/canvases/getWorkspaces")
local shared = require("@root/server/routes/shared")
local useWorkspace = require("@root/storage/canvases/useWorkspace")

type Response = shared.Response

local canvases = {}

function canvases.handle(
	request: net.ReceivedRequest,
	root: string,
	getActive: () -> string,
	switchTo: (string) -> ()
): Response
	local didSucceed, response = pcall(function(): Response
		if request.path == "/api/canvases" and request.method == "GET" then
			local list = getWorkspaces(root)
			return shared.reply(200, json.object({ active = getActive(), canvases = list.workspaces }))
		elseif request.path == "/api/canvases" and request.method == "POST" then
			local change = shared.parseBody(request)
			local name = getStringField(change.name)
			assert(name, `invalid canvas name: {tostring(change.name)}`)
			local label = getStringField(change.label)
			assert(change.label == nil or label, "label must be nonempty")
			local list = createWorkspace(root, name, label)
			return shared.reply(201, json.object({ active = getActive(), canvases = list.workspaces }))
		elseif request.path == "/api/canvases/active" and request.method == "POST" then
			local name = getStringField(shared.parseBody(request).name)
			assert(name, "invalid canvas name")
			local list = useWorkspace(root, name)
			switchTo(name)
			return shared.reply(200, json.object({ active = getActive(), canvases = list.workspaces }))
		end
		return shared.reply(404, json.object({ error = "not found" }))
	end)
	return if didSucceed then response :: Response else shared.reply(400, json.object({ error = tostring(response) }))
end

return table.freeze(canvases)
