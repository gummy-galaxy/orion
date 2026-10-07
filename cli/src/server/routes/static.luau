local filesystem = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")

local shared = require("@root/server/routes/shared")

local static = {}

local function getContentType(file: string): string
	local extension = file:match("%.([^.]+)$")
	if extension == "html" then
		return "text/html; charset=utf-8"
	end
	if extension == "js" then
		return "text/javascript; charset=utf-8"
	end
	if extension == "css" then
		return "text/css; charset=utf-8"
	end
	if extension == "json" then
		return "application/json"
	end
	if extension == "svg" then
		return "image/svg+xml"
	end
	if extension == "png" then
		return "image/png"
	end
	if extension == "ico" then
		return "image/x-icon"
	end
	if extension == "woff2" then
		return "font/woff2"
	end
	return "application/octet-stream"
end

function static.serve(folder: string, requestPath: string): shared.Response
	local name = requestPath:gsub("^/", "")
	if name == "" then
		name = "index.html"
	end
	if name:find("..", 1, true) or name:find("\\", 1, true) then
		return shared.reply(404, json.object({ error = "not found" }))
	end
	local file = tostring(path.join(folder, name))
	if not filesystem.exists(file) or filesystem.type(file) ~= "file" then
		file = tostring(path.join(folder, "index.html"))
	end
	if not filesystem.exists(file) then
		return shared.reply(404, json.object({ error = "not found" }))
	end
	return {
		status = 200,
		body = filesystem.readFileToString(file),
		headers = { ["content-type"] = getContentType(file) },
	}
end

return table.freeze(static)
