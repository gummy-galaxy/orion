local json = require("@std/json")

local encodeStableJson = require("@root/storage/files/encodeStableJson")
local fileNames = require("@root/fileNames")

type Sides = { ours: string, theirs: string, oursName: string, theirsName: string }

local function parseObject(text: string): json.Object?
	local succeeded, value = pcall(json.deserialize, text)
	return if succeeded then json.asObject(value) else nil
end

-- Splits text with git's conflict markers into the two sides, or nil when it
-- has none. A diff3 base section, after `|||||||`, belongs to neither side.
local function splitConflict(text: string): Sides?
	if not text:find("^<<<<<<< ") and not text:find("\n<<<<<<< ") then
		return nil
	end

	local ours: { string } = {}
	local theirs: { string } = {}
	local oursName, theirsName = "ours", "theirs"
	local section = "both"

	for line in (text .. "\n"):gmatch("([^\n]*)\n") do
		local opening = line:match("^<<<<<<< ?(.*)$")
		local closing = line:match("^>>>>>>> ?(.*)$")

		if opening then
			section = "ours"
			oursName = if opening ~= "" then opening else oursName
		elseif line:find("^|||||||") then
			section = "base"
		elseif line:find("^=======$") and section ~= "both" then
			section = "theirs"
		elseif closing and section ~= "both" then
			section = "both"
			theirsName = if closing ~= "" then closing else theirsName
		else
			if section == "both" or section == "ours" then
				table.insert(ours, line)
			end

			if section == "both" or section == "theirs" then
				table.insert(theirs, line)
			end
		end
	end

	return {
		ours = table.concat(ours, "\n"),
		theirs = table.concat(theirs, "\n"),
		oursName = oursName,
		theirsName = theirsName,
	}
end

local function getNote(object: json.Object?): string
	local data = if object then json.asObject(object.data) else nil
	return if data and type(data.note) == "string" then data.note else ""
end

-- The id a node file is named for, read back from the escapes
-- `getEntryFileName` writes.
local function getFileId(file: string): string
	local name = file:match("^[^/]+/(.*)%.json$") or file
	local id = name:gsub("%%(%x%x)", function(hex: string): string
		return string.char(tonumber(hex, 16) :: number)
	end)

	return id
end

local function resolveConflict(file: string, sides: Sides): (json.Object?, string)
	local ours, theirs = parseObject(sides.ours), parseObject(sides.theirs)
	local kept = ours or theirs

	if not kept then
		return nil, `{file} has a git conflict and neither side is a JSON object`
	end

	local keptName = if ours then sides.oursName else sides.theirsName
	local oursNote, theirsNote = getNote(ours), getNote(theirs)

	if ours and theirs and oursNote ~= theirsNote then
		local data = json.asObject(kept.data) or json.object({})
		data.note = table.concat({
			`<<<<<<< {sides.oursName}`,
			oursNote,
			"=======",
			theirsNote,
			`>>>>>>> {sides.theirsName}`,
		}, "\n")
		kept.data = data

		return kept, `{file} has a git conflict; kept {keptName}'s fields and both versions of its note`
	end

	return kept, `{file} has a git conflict; kept {keptName}'s side`
end

-- A node file nothing can be read from still shows, as a note holding its text,
-- so it isn't lost from the canvas.
local function getUnreadableNode(file: string, text: string): json.Object
	return json.object({
		id = getFileId(file),
		type = "task",
		position = json.object({ x = 0, y = 0 }),
		data = json.object({
			kind = "task",
			itemKind = "note",
			label = `Unreadable {file}`,
			note = `This file isn't valid JSON, so Orion shows its text here. Fix the file to bring the card back.\n`
				.. `\n\`\`\`\n{text}\n\`\`\``,
		}),
	})
end

--[[
	Makes a canvas folder's files readable, keyed by path as `joinCanvasFiles`
	takes them, and returns the problems it worked around. A file with git's
	conflict markers keeps one side, ours when it parses, and when the two sides
	disagree on a note, its note holds both versions between the markers so it
	shows as a conflicted note. Any other node file that isn't a JSON object
	becomes a note holding its text. A link or `local.json` that can't be read
	is left out. `canvas.json` must parse on one side, since nothing else holds
	the canvas's settings.
]]
local function resolveCanvasFiles(files: { [string]: string }): ({ [string]: string }, { string })
	local resolved: { [string]: string } = {}
	local problems: { string } = {}

	for file, text in files do
		if parseObject(text) then
			resolved[file] = text
			continue
		end

		local sides = splitConflict(text)
		local object: json.Object?, problem: string

		if sides then
			object, problem = resolveConflict(file, sides)
		else
			object, problem = nil, `{file} isn't a JSON object`
		end

		if not object and file:find(`^{fileNames.nodes}/`) then
			object = getUnreadableNode(file, text)
			problem ..= "; it shows as a note holding its text"
		end

		assert(object or file ~= fileNames.document, problem)
		table.insert(problems, problem)

		if object then
			resolved[file] = encodeStableJson(object)
		end
	end

	table.sort(problems)

	return resolved, problems
end

return resolveCanvasFiles
