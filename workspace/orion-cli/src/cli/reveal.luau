local cli = require("@batteries/cli")
local json = require("@std/json")
local net = require("@std/net")
local path = require("@std/path")
local process = require("@std/process")
local task = require("@std/task")

local addArgument = require("@root/cli/addArgument")
local context = require("@root/cli/context")
local getRunningRuntime = require("@root/server/getRunningRuntime")
local getWorkspaceDir = require("@root/store/getWorkspaceDir")
local getWorkspaces = require("@root/store/getWorkspaces")
local isProcessAlive = require("@root/server/isProcessAlive")
local loadDoc = require("@root/store/loadDoc")
local readFocus = require("@root/store/readFocus")
local readRuntime = require("@root/server/readRuntime")
local types = require("@root/types")

type Context = context.Context
type Focus = types.Focus
type Runtime = readRuntime.Runtime

-- How long a reveal waits for a freshly opened app to start serving and connect, and then to report what it shows.
local OPEN_ATTEMPTS = 60
local CONFIRM_ATTEMPTS = 20
local POLL_SECONDS = 0.5
local CONFIRM_SECONDS = 0.25

local function findRuntime(options: Context): Runtime?
	return getRunningRuntime(options.root, function(pid)
		return isProcessAlive(pid, options.runner)
	end)
end

-- Finds the canvas holding every id: the one named with --canvas, or else the selected canvas and then the others.
local function chooseCanvas(options: Context, ids: { string }): string
	local candidates: { string } = {}

	if options.requestedWorkspace then
		table.insert(candidates, options.requestedWorkspace)
	else
		table.insert(candidates, options.workspace)

		for _, entry in getWorkspaces(options.root).workspaces do
			if entry.name ~= options.workspace then
				table.insert(candidates, entry.name)
			end
		end
	end

	local missing: string? = nil

	for _, name in candidates do
		local present: { [string]: boolean } = {}

		for _, node in loadDoc(getWorkspaceDir(options.root, name)).nodes do
			present[node.id] = true
		end

		local found = true

		for _, id in ids do
			if not present[id] then
				found = false
				missing = missing or id
			end
		end

		if found then
			return name
		end
	end

	if options.requestedWorkspace then
		error(`"{missing}" isn't on canvas {options.requestedWorkspace}`, 0)
	end

	error(`"{missing}" isn't on canvas {options.workspace} or any other canvas`, 0)
end

-- Launches the installed app against this data folder, so the server it starts serves the same canvases.
local function openAppAsync(options: Context)
	local app = path.join(process.homedir(), "Applications", "Orion.app")
	local result = options.runner({ "open", "--env", `ORION_DATA_DIR={options.root}`, "-a", tostring(app) }, nil)

	if not result.ok then
		error(`Could not open Orion at {app}. Open it yourself, then run this again.`, 0)
	end
end

-- Returns the HTTP status and the error text, if any. A status of 0 means nothing answered.
local function postReveal(runtime: Runtime, body: string): (number, string?)
	local didRequest, response = pcall(function()
		return net.request(`{runtime.url}/api/reveal`, {
			method = "POST",
			body = body,
			headers = { ["content-type"] = "application/json" },
		})
	end)

	if not didRequest then
		return 0, nil
	end

	if response.status == 200 then
		return 200, nil
	end

	local value = json.asObject(json.deserialize(response.body) :: json.Value)
	local message = if value then value.error else nil
	return response.status, if type(message) == "string" then message else nil
end

-- The focus the app reports once it has shown the ids, or nil if it never reports them. Older reports don't count.
local function confirmReveal(dir: string, ids: { string }, requestedAt: string): Focus?
	for _ = 1, CONFIRM_ATTEMPTS do
		local focus = readFocus(dir)

		if focus and focus.updatedAt and focus.updatedAt >= requestedAt then
			local selected: { [string]: boolean } = {}

			for _, id in focus.selected do
				selected[id] = true
			end

			local all = true

			for _, id in ids do
				all = all and selected[id] == true
			end

			if all then
				return focus
			end
		end

		task.wait(CONFIRM_SECONDS)
	end

	return nil
end

return table.freeze({
	help = "Select cards or groups in the app and zoom the canvas to them",
	mcp = {
		description = "Select cards or groups in the open Orion app and zoom the canvas to them, opening the group they share. Opens the app when it's closed. Set selectOnly to select without moving the camera.",
	},
	define = function(parser: cli.Parser)
		addArgument(parser, "ids", "variadic", { help = "Item or group ids to reveal", mcp = { required = true } })
		parser:add("select-only", "flag", { help = "Select them without moving the camera" })
		parser:add("json", "flag", { help = "Print JSON" })
	end,

	run = function(parser: cli.Parser, options: Context)
		local ids = parser:variadics()
		assert(#ids > 0, "say what to reveal, such as orion reveal <id>")

		local canvas = chooseCanvas(options, ids)
		local list: json.Array = {}

		for _, id in ids do
			table.insert(list, id)
		end

		local body =
			json.serialize(json.object({ canvas = canvas, ids = list, selectOnly = parser:has("select-only") }))
		local dir = getWorkspaceDir(options.root, canvas)
		local requestedAt = options.now()
		local launched = false
		local accepted = false

		if findRuntime(options) == nil then
			openAppAsync(options)
			launched = true
		end

		for _ = 1, OPEN_ATTEMPTS do
			local runtime = findRuntime(options)

			if runtime then
				local status, message = postReveal(runtime, body)

				if status == 200 then
					accepted = true
					break
				end

				-- An app that's still starting shows up as nothing answering, or as no app connected yet.
				local waiting = launched and (status == 0 or status == 409)

				if status == 0 and not launched then
					error("The Orion server isn't responding. Restart Orion and try again.", 0)
				end

				-- A server built before reveal answers its unknown routes with a plain "not found".
				if status == 404 and message == "not found" then
					error(
						"The running Orion server doesn't have reveal. Rebuild and reinstall the app, then try again.",
						0
					)
				end

				if status == 409 and not launched then
					error("Orion isn't open, so nothing can be revealed. Open Orion and try again.", 0)
				end

				if not waiting then
					error(message or "Orion couldn't reveal those items.", 0)
				end
			end

			task.wait(POLL_SECONDS)
		end

		if not accepted then
			error("Orion didn't start in time. Open it and try again.", 0)
		end

		local focus = confirmReveal(dir, ids, requestedAt)

		if not focus then
			error("Orion didn't show those items. Check that the app is open, then try again.", 0)
		end

		if parser:has("json") then
			local selected: json.Array = {}

			for _, id in focus.selected do
				table.insert(selected, id)
			end

			options.write(
				json.serialize(
					json.object({ canvas = canvas, open = focus.open or json.null, selected = selected }),
					true
				)
			)
		else
			options.write(`Revealed {table.concat(ids, ", ")} on canvas {canvas}.`)
		end
	end,
})
