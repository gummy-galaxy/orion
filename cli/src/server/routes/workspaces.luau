local json = require("@std/json")
local net = require("@lute/net/server")

local getStringField = require("@root/getStringField")
local shared = require("@root/server/routes/shared")
local store = require("@root/store")

type Response = shared.Response

local workspaces = {}

function workspaces.handle(
	request: net.ReceivedRequest,
	root: string,
	getActive: () -> string,
	switchTo: (string) -> ()
): Response
	local didSucceed, response = pcall(function(): Response
		if request.path == "/api/workspaces" and request.method == "GET" then
			local list = store.getWorkspaces(root)
			return shared.reply(200, json.object({ active = getActive(), workspaces = list.workspaces }))
		elseif request.path == "/api/workspaces" and request.method == "POST" then
			local change = shared.parseBody(request)
			local name = getStringField(change.name)
			assert(name, `invalid workspace name: {tostring(change.name)}`)
			local label = getStringField(change.label)
			assert(change.label == nil or label, "label must be nonempty")
			local list = store.createWorkspace(root, name, label)
			return shared.reply(201, json.object({ active = getActive(), workspaces = list.workspaces }))
		elseif request.path == "/api/workspaces/active" and request.method == "POST" then
			local name = getStringField(shared.parseBody(request).name)
			assert(name, "invalid workspace name")
			local list = store.useWorkspace(root, name)
			switchTo(name)
			return shared.reply(200, json.object({ active = getActive(), workspaces = list.workspaces }))
		end
		return shared.reply(404, json.object({ error = "not found" }))
	end)
	return if didSucceed then response :: Response else shared.reply(400, json.object({ error = tostring(response) }))
end

return table.freeze(workspaces)
