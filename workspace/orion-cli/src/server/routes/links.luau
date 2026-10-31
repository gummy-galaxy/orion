local json = require("@std/json")
local net = require("@lute/net/server")

local getErrorText = require("@root/common/errors/getErrorText")
local getLabel = require("@root/canvas/items/getLabel")
local getStringField = require("@root/common/getStringField")
local getWorkspaceDir = require("@root/storage/canvases/getWorkspaceDir")
local loadDoc = require("@root/storage/canvases/loadDoc")
local lookupCardAsync = require("@root/sources/import/lookupCardAsync")
local readSourceCommands = require("@root/sources/readSourceCommands")
local runCommand = require("@root/common/process/command")
local shared = require("@root/server/routes/shared")
local types = require("@root/types")

type CommandRunner = types.CommandRunner
type Response = shared.Response

local links = {}

-- Looks up the card a pasted link would make, without saving it, so the app can
-- place the card where it was asked for.
function links.handleAsync(request: net.ReceivedRequest, root: string, runner: CommandRunner?): Response
	if request.method ~= "POST" then
		return shared.reply(405, json.object({ error = "method not allowed" }))
	end

	local workspace = request.query.canvas
	if not workspace or not shared.isKnownWorkspace(root, workspace) then
		return shared.reply(404, json.object({ error = `unknown canvas: {workspace or ""}` }))
	end

	local parsed, body = pcall(shared.parseBody, request)
	local url = if parsed then getStringField(body.url) else nil
	if not url or not url:match("^https?://%S+$") then
		return shared.reply(400, json.object({ error = "expected a URL" }))
	end

	local doc = loadDoc(getWorkspaceDir(root, workspace))
	local now = os.date("!%Y-%m-%dT%H:%M:%SZ") :: string
	local succeeded, result =
		pcall(lookupCardAsync, url, doc, readSourceCommands(root, workspace), now, runner or runCommand)
	if not succeeded then
		return shared.reply(422, json.object({ error = getErrorText(result) }))
	end

	local item = result.item
	if result.status == "existing" then
		return shared.reply(200, json.object({ status = "existing", id = item.id, label = getLabel(item) }))
	end

	return shared.reply(200, json.object({ status = "found", id = item.id, data = item.data }))
end

return table.freeze(links)
