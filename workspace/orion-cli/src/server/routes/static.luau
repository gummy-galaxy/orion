local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")

local shared = require("@root/server/routes/shared")

local static = {}

-- The desktop shell sets no policy of its own. Fonts come from Google Fonts, and link favicons and card
-- images from any https site. `host` is the address the page was loaded from, already checked by the
-- server, and names the WebSocket since some WebKit versions don't match `ws:` against `'self'`.
local function getContentSecurityPolicy(host: string?): string
	local connect = if host then `'self' ws://{host} ipc: http://ipc.localhost` else "'self' ipc: http://ipc.localhost"

	return table.concat({
		"default-src 'self'",
		"script-src 'self'",
		"style-src 'self' https://fonts.googleapis.com",
		"font-src 'self' https://fonts.gstatic.com",
		"img-src 'self' data: blob: https:",
		`connect-src {connect}`,
		"object-src 'none'",
		"base-uri 'none'",
		"form-action 'none'",
		"frame-ancestors 'none'",
	}, "; ")
end

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

function static.serve(folder: string, requestPath: string, host: string?): shared.Response
	local name = requestPath:gsub("^/", "")
	if name == "" then
		name = "index.html"
	end
	if name:find("..", 1, true) or name:find("\\", 1, true) then
		return shared.reply(404, json.object({ error = "not found" }))
	end
	local file = tostring(path.join(folder, name))
	if not fs.exists(file) or fs.type(file) ~= "file" then
		file = tostring(path.join(folder, "index.html"))
	end
	if not fs.exists(file) then
		return shared.reply(404, json.object({ error = "not found" }))
	end
	local contentType = getContentType(file)
	local headers = { ["content-type"] = contentType }
	if contentType:sub(1, 9) == "text/html" then
		headers["content-security-policy"] = getContentSecurityPolicy(host)
	end

	return { status = 200, body = fs.readFileToString(file), headers = headers }
end

return table.freeze(static)
