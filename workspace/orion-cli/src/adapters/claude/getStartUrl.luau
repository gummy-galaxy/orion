local adapterTypes = require("@root/adapters/types")
local encodeUrlComponent = require("@root/encodeUrlComponent")
local types = require("@root/types")

type Source = types.Source
type StartRequest = adapterTypes.StartRequest

-- Claude Desktop cuts a linked prompt off at about this many characters.
local MAX_PROMPT_LENGTH = 14000

--[[
	A Claude Desktop link that opens a new Claude Code session in the folder
	with the prompt filled in. Desktop asks the person to confirm the folder,
	and nothing runs until they send the prompt.
]]
local function getStartUrl(_source: Source, request: StartRequest): string
	local prompt = request.prompt:sub(1, MAX_PROMPT_LENGTH)
	return `claude://code/new?folder={encodeUrlComponent(request.cwd)}&q={encodeUrlComponent(prompt)}`
end

return getStartUrl
