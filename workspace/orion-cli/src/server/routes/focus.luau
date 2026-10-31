local json = require("@std/json")
local net = require("@lute/net/server")

local getStringField = require("@root/common/getStringField")
local getWorkspaceDir = require("@root/storage/canvases/getWorkspaceDir")
local putFocus = require("@root/storage/focus/putFocus")
local shared = require("@root/server/routes/shared")

type Response = shared.Response

local focus = {}

function focus.handle(request: net.ReceivedRequest, root: string, active: string): Response
	if request.method ~= "POST" then
		return shared.reply(405, json.object({ error = "method not allowed" }))
	end

	local didSucceed, response = pcall(function(): Response
		local report = shared.parseBody(request)
		local tab = getStringField(report.tab)
		local workspace = getStringField(report.canvas)
		assert(tab and tab ~= "", "tab must be a nonempty string")
		assert(workspace, "canvas must be a string")

		if not shared.isKnownWorkspace(root, workspace) then
			return shared.reply(404, json.object({ error = `unknown canvas: {workspace}` }))
		end

		local isClosed = report.closed == true
		if not isClosed and workspace ~= active then
			return shared.reply(409, json.object({ error = "canvas changed" }))
		end

		local open = if report.open == json.null then nil else getStringField(report.open)
		local selected = if isClosed then nil else json.asArray(report.selected)
		if not isClosed then
			assert(report.open == json.null or open, "open must be a string or null")
			assert(selected, "selected must be an array")
			for _, id in selected :: json.Array do
				assert(type(id) == "string", "selected must contain strings")
			end
		end

		putFocus(getWorkspaceDir(root, workspace), tab, open, selected, isClosed)
		return shared.reply(200, json.object({}))
	end)

	return if didSucceed then response :: Response else shared.reply(400, json.object({ error = tostring(response) }))
end

return table.freeze(focus)
