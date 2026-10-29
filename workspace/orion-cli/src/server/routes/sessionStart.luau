local json = require("@std/json")
local net = require("@lute/net/server")

local describeStartOptions = require("@root/sessions/describeStartOptions")
local getErrorText = require("@root/getErrorText")
local getStartOptionsAsync = require("@root/sessions/getStartOptionsAsync")
local getStringField = require("@root/getStringField")
local getWorkspaceDir = require("@root/store/getWorkspaceDir")
local isGroup = require("@root/graph/isGroup")
local loadDoc = require("@root/store/loadDoc")
local readSourceCommands = require("@root/sources/readSourceCommands")
local runCommand = require("@root/command")
local shared = require("@root/server/routes/shared")
local startSessionAsync = require("@root/sessions/startSessionAsync")
local types = require("@root/types")

type CommandRunner = types.CommandRunner
type Item = types.Item
type Response = shared.Response

local sessionStart = {}

local function findCard(nodes: { Item }, id: string): Item?
	for _, node in nodes do
		if node.id == id and not isGroup(node) then
			return node
		end
	end

	return nil
end

--[[
	Starting an agent session from a card in the app. GET answers what a start
	would do for `?id=`, so the app can offer the presets that fit. POST with
	`{ id, preset }` opens the agent on this machine, the way orion session
	start does.
]]
function sessionStart.handleAsync(
	request: net.ReceivedRequest,
	root: string,
	active: string,
	runner: CommandRunner?
): Response
	local run = runner or runCommand
	local isPost = request.method == "POST"

	if request.method ~= "GET" and not isPost then
		return shared.reply(405, json.object({ error = "method not allowed" }))
	end

	local parsed, body = pcall(shared.parseBody, request)
	local fields = if isPost and parsed then body else json.object({})
	local canvas = getStringField(fields.canvas) or request.query.canvas or active
	local id = getStringField(fields.id) or request.query.id

	if isPost and not parsed then
		return shared.reply(400, json.object({ error = "expected a JSON body" }))
	elseif not shared.isKnownWorkspace(root, canvas) then
		return shared.reply(404, json.object({ error = `unknown canvas: {canvas}` }))
	end

	local doc = loadDoc(getWorkspaceDir(root, canvas))
	local item = if id then findCard(doc.nodes, id) else nil

	if not item then
		return shared.reply(404, json.object({ error = `no card {id or ""}` }))
	end

	local commands = readSourceCommands(root, canvas)

	if not isPost then
		return shared.reply(200, describeStartOptions(getStartOptionsAsync(doc, item, run, commands)))
	end

	local succeeded, start =
		pcall(startSessionAsync, doc, item, getStringField(fields.preset) or "work", run, commands, true)

	if not succeeded then
		return shared.reply(409, json.object({ error = getErrorText(start) }))
	end

	return shared.reply(200, json.object({ agent = start.agent, folder = start.folder, url = start.url }))
end

return table.freeze(sessionStart)
