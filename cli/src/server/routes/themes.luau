local json = require("@std/json")
local net = require("@lute/net/server")

local readThemeFiles = require("@root/themes/readThemeFiles")
local shared = require("@root/server/routes/shared")

type Response = shared.Response

local themes = {}

-- Lists the theme files in the data folder. Read only: the app parses and checks each one.
function themes.handle(request: net.ReceivedRequest, root: string): Response
	if request.method ~= "GET" then
		return shared.reply(405, json.object({ error = "method not allowed" }))
	end

	local entries: { json.Value } = {}
	for _, theme in readThemeFiles(root) do
		table.insert(entries, json.object({ file = theme.file, text = theme.text, error = theme.error }))
	end

	return shared.reply(200, json.object({ themes = entries }))
end

return table.freeze(themes)
