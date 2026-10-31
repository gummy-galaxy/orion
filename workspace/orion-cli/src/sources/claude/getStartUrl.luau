local adapterTypes = require("@root/sources/types")
local encodeUrlComponent = require("@root/common/encodeUrlComponent")
local types = require("@root/types")

type Source = types.Source
type StartRequest = adapterTypes.StartRequest

-- Claude Desktop cuts a linked prompt off at about this many characters.
local MAX_PROMPT_LENGTH = 14000

--[[
	A Claude Desktop link that opens a new Claude Code session in the folder
	with the prompt filled in. Desktop asks the person to confirm the folder,
	or to pick one when there's none, and nothing runs until they send the
	prompt.
]]
local function getStartUrl(_source: Source, request: StartRequest): string
	local query = `q={encodeUrlComponent(request.prompt:sub(1, MAX_PROMPT_LENGTH))}`

	if request.cwd then
		query = `folder={encodeUrlComponent(request.cwd)}&{query}`
	end

	return `claude://code/new?{query}`
end

return getStartUrl
