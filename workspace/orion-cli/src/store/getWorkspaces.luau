local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")

local fileNames = require("@root/fileNames")
local getStringField = require("@root/getStringField")
local isValidWorkspace = require("@root/store/isValidWorkspace")
local storeTypes = require("@root/store/types")

type WorkspaceList = storeTypes.WorkspaceList

-- Reads the workspace list. Without a list file, there's only the default workspace.
local function getWorkspaces(root: string): WorkspaceList
	local file = tostring(path.join(root, fileNames.canvases))
	local result: WorkspaceList =
		{ active = "default", workspaces = { { name = "default", label = "Default" } }, archived = {} }

	if not fs.exists(file) then
		return result
	end

	local raw = json.asObject(json.deserialize(fs.readFileToString(file)) :: json.Value)
	assert(raw, `invalid canvas list at {file}`)

	local names: { [string]: boolean } = { default = true }

	for _, entry in json.asArray(raw.canvases) or {} do
		local item = json.asObject(entry)
		local name = if item then getStringField(item.name) else nil
		local label = if item then getStringField(item.label) else nil
		assert(name and isValidWorkspace(name) and label and label ~= "", `invalid canvas in {file}`)

		if name == "default" then
			result.workspaces[1].label = label
		elseif not names[name] then
			table.insert(result.workspaces, { name = name, label = label })
			names[name] = true
		end
	end

	for _, entry in json.asArray(raw.archived) or {} do
		local item = json.asObject(entry)
		local name = if item then getStringField(item.name) else nil
		local label = if item then getStringField(item.label) else nil
		assert(name and isValidWorkspace(name) and label and label ~= "", `invalid archived canvas in {file}`)
		assert(not names[name], `canvas listed twice in {file}: {name}`)
		names[name] = true
		table.insert(result.archived, { name = name, label = label })
	end

	local active = getStringField(raw.active) or "default"
	assert(names[active], `unknown canvas: {active}`)
	result.active = active

	return result
end

return getWorkspaces
