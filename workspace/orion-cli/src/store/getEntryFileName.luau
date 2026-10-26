-- Names Windows reserves for devices, which no file may take whatever its
-- extension.
local RESERVED: { [string]: boolean } = {
	con = true,
	prn = true,
	aux = true,
	nul = true,
}

local function encodeByte(character: string): string
	return string.format("%%%02x", string.byte(character))
end

--[[
	The file name a node or link with this id is stored under, such as
	`nodes/<name>`. Lowercase letters, digits, hyphens, and underscores stay as
	they are, and every other byte is written as `%` and two hex digits.
	Uppercase letters are escaped too, so two ids that differ only in case get
	different files on a case-insensitive disk. The file holds its own id, so
	the name is only ever written, never read back.
]]
local function getEntryFileName(id: string): string
	local name = id:gsub("[^a-z0-9_%-]", encodeByte)
	local base = name:match("^(%a+)%d?$")

	-- An escape always has two hex digits after it, so a lone `%` can't collide
	-- with another id.
	if name == "" then
		name = "%"
	elseif base and (RESERVED[base] or ((base == "com" or base == "lpt") and #name == 4)) then
		name = encodeByte(name:sub(1, 1)) .. name:sub(2)
	end

	return `{name}.json`
end

return getEntryFileName
