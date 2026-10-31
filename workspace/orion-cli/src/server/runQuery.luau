local json = require("@std/json")

local getWorkspaceDir = require("@root/storage/canvases/getWorkspaceDir")
local parseSort = require("@root/canvas/query/parseSort")
local queryItems = require("@root/canvas/query/queryItems")
local readDoc = require("@root/storage/canvases/readDoc")
local render = require("@root/canvas/render")

-- Reads an optional field of one type, refusing any other.
local function readField(request: json.Object, name: string, kind: string): any
	local value = request[name]
	if value ~= nil and type(value) ~= kind then
		error(`{name} must be a {kind}`, 0)
	end

	return value
end

-- Answers a query for the app, over HTTP or the event socket. The request
-- takes `orion node query`'s options as fields: `where`, `sort`, `offset`,
-- `limit`, and `all`, with a blank `where` matching every node. The answer is
-- one page of rows, each shaped as `orion node query --json` prints a node,
-- with the revision they were read at and how many nodes match in all.
local function runQuery(root: string, canvas: string, request: json.Object): json.Object
	local where: string? = readField(request, "where", "string")
	local sort: string? = readField(request, "sort", "string")
	local doc = readDoc(getWorkspaceDir(root, canvas))

	if not doc then
		error(`canvas {canvas} has no files yet`, 0)
	end

	local result = queryItems(doc, {
		where = if where and where:match("%S") then where else nil,
		sort = if sort and sort ~= "" then parseSort(sort) else nil,
		offset = readField(request, "offset", "number"),
		limit = readField(request, "limit", "number"),
		includeDone = readField(request, "all", "boolean"),
	})
	local rows: json.Array = {}

	for _, item in result.items do
		table.insert(rows, render.itemJson(doc, result.derived, item))
	end

	return json.object({
		canvas = canvas,
		revision = doc.revision,
		total = result.total,
		offset = result.offset,
		rows = rows,
	})
end

return runQuery
