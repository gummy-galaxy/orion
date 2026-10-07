local json = require("@std/json")
local network = require("@lute/net/server")

local shared = require("@root/server/routes/shared")
local store = require("@root/store")

type Response = shared.Response

local focus = {}

function focus.handle(request: network.ReceivedRequest, root: string, active: string): Response
	if request.method ~= "POST" then
		return shared.reply(405, json.object({ error = "method not allowed" }))
	end

	local didSucceed, response = pcall(function(): Response
		local report = shared.parseBody(request)
		local tab = shared.getStringField(report.tab)
		local workspace = shared.getStringField(report.workspace)
		assert(tab and tab ~= "", "tab must be a nonempty string")
		assert(workspace, "workspace must be a string")

		if not shared.isKnownWorkspace(root, workspace) then
			return shared.reply(404, json.object({ error = `unknown workspace: {workspace}` }))
		end

		local isClosed = report.closed == true
		if not isClosed and workspace ~= active then
			return shared.reply(409, json.object({ error = "workspace changed" }))
		end

		local open = if report.open == json.null then nil else shared.getStringField(report.open)
		local selected = if isClosed then nil else json.asArray(report.selected)
		if not isClosed then
			assert(report.open == json.null or open, "open must be a string or null")
			assert(selected, "selected must be an array")
			for _, id in selected :: json.Array do
				assert(type(id) == "string", "selected must contain strings")
			end
		end

		store.putFocus(store.getWorkspaceDirectory(root, workspace), tab, open, selected, isClosed)
		return shared.reply(200, json.object({}))
	end)

	return if didSucceed then response :: Response else shared.reply(400, json.object({ error = tostring(response) }))
end

return table.freeze(focus)
