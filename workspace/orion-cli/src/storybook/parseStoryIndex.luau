local json = require("@std/json")
local path = require("@std/path")

local getStringField = require("@root/getStringField")
local types = require("@root/storybook/types")

type ReadFile = types.ReadFile
type Story = types.Story

local function getExportOrder(source: string): { [string]: number }
	local order = {}
	local count = 0

	for name in string.gmatch(source, "export%s+const%s+([%w_]+)") do
		if order[name] == nil then
			count += 1
			order[name] = count
		end
	end

	return order
end

--[[
	Reads the stories in a built Storybook's index.json. `root` is the folder
	Storybook ran from, relative to the repository root, since the index records
	each stories file relative to it. Each story is ordered by where its export
	sits in its stories file, which `readFile` reads; a story whose export isn't
	found sorts last.
]]
local function parseStoryIndex(indexText: string, root: string, readFile: ReadFile): { Story }
	local index: json.Object = json.asObject(json.deserialize(indexText) :: json.Value) or {}
	local entries: json.Object = json.asObject(index.entries) or {}
	local exportOrders: { [string]: { [string]: number } } = {}
	local stories = {}

	for _, value in entries do
		local entry = json.asObject(value)
		local id = entry and getStringField(entry.id)
		local name = entry and getStringField(entry.name)
		local title = entry and getStringField(entry.title)
		local importPath = entry and getStringField(entry.importPath)

		if not (entry and entry.type == "story" and id and name and title and importPath) then
			continue
		end

		local file = tostring(path.normalize(path.join(root, importPath)))

		if exportOrders[file] == nil then
			local source = readFile(file)
			exportOrders[file] = if source then getExportOrder(source) else {}
		end

		local exportName = getStringField(entry.exportName)
		local order = if exportName then exportOrders[file][exportName] else nil

		table.insert(stories, { id = id, name = name, title = title, file = file, order = order or math.huge })
	end

	return stories
end

return parseStoryIndex
