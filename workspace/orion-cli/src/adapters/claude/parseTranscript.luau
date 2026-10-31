local json = require("@std/json")

local adapterTypes = require("@root/adapters/types")
local claudeTypes = require("@root/adapters/claude/types")
local trimText = require("@root/trimText")

type Transcript = claudeTypes.Transcript
type Turn = adapterTypes.Turn

local TEXT_LIMIT = 2000

local function getString(value: json.Value): string?
	return if type(value) == "string" then value else nil
end

-- Text with the reminders the harness adds taken out. Nil when what's left is
-- empty or another harness tag.
local function getProse(text: string): string?
	local prose = text:gsub("<system%-reminder>.-</system%-reminder>", ""):match("^%s*(.-)%s*$") or ""
	return if prose == "" or prose:sub(1, 1) == "<" then nil else prose
end

-- The prose in a message, leaving out tool calls, tool results, and the
-- reminders and command tags the harness adds.
local function getText(content: json.Value): string?
	if type(content) == "string" then
		return getProse(content)
	end

	local parts: { string } = {}

	for _, raw in json.asArray(content) or {} do
		local block = json.asObject(raw)
		local text = if block and block.type == "text" then getString(block.text) else nil
		local prose = if text then getProse(text) else nil

		if prose then
			table.insert(parts, prose)
		end
	end

	return if #parts > 0 then table.concat(parts, "\n\n") else nil
end

local function hasBlock(content: json.Value, kind: string): boolean
	for _, raw in json.asArray(content) or {} do
		local block = json.asObject(raw)

		if block and block.type == kind then
			return true
		end
	end

	return false
end

--[[
	Reads a Claude Code transcript's JSON lines: the branch and folder it ran
	in, its title, its recent turns, and whose move it is. A turn that ended,
	stopped on a tool call with no result, or was interrupted is your move. A
	tool result or a new prompt means the agent is working.
]]
local function parseTranscript(text: string): Transcript
	local result: Transcript = { state = "working", turns = {} }
	local customTitle: string? = nil
	local agentName: string? = nil

	for line in text:gmatch("[^\n]+") do
		local succeeded, decoded = pcall(json.deserialize, line)
		local entry = if succeeded then json.asObject(decoded) else nil

		if not entry then
			continue
		end

		if entry.type == "custom-title" then
			customTitle = getString(entry.customTitle) or customTitle
			continue
		elseif entry.type == "agent-name" then
			agentName = getString(entry.agentName) or agentName
			continue
		elseif (entry.type ~= "user" and entry.type ~= "assistant") or entry.isSidechain == true then
			continue
		end

		result.branch = getString(entry.gitBranch) or result.branch
		result.cwd = getString(entry.cwd) or result.cwd
		result.lastAt = getString(entry.timestamp) or result.lastAt
		local message = json.asObject(entry.message)

		if not message then
			continue
		end

		local content = message.content
		local said = if entry.isMeta == true then nil else getText(content)

		if entry.type == "assistant" then
			local stop = getString(message.stop_reason)
			result.state = if stop == "end_turn" or hasBlock(content, "tool_use") then "waiting" else "working"
		elseif hasBlock(content, "tool_result") then
			result.state = "working"
		elseif said then
			result.state = if said:find("[Request interrupted", 1, true) then "waiting" else "working"
		end

		if said then
			local role: "you" | "agent" = if entry.type == "assistant" then "agent" else "you"
			local trimmed = trimText(said, TEXT_LIMIT)
			table.insert(result.turns, { role = role, text = trimmed, at = result.lastAt } :: Turn)

			if role == "agent" then
				result.lastMessage = trimmed
			end
		end
	end

	result.title = customTitle or agentName
	return result
end

return parseTranscript
