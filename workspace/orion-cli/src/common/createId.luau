local crypto = require("@lute/crypto")

--[[
	A random version 4 UUID for a new node, link, or placement. Ids made from
	labels or counters collide when two branches of a canvas each add one, and
	random ones never do, so git merges them as separate files.
]]
local function createId(): string
	local bytes = crypto.secretbox.keygen()
	buffer.writeu8(bytes, 6, bit32.bor(bit32.band(buffer.readu8(bytes, 6), 0x0f), 0x40))
	buffer.writeu8(bytes, 8, bit32.bor(bit32.band(buffer.readu8(bytes, 8), 0x3f), 0x80))

	local hex = buffer.tostring(bytes):sub(1, 16):gsub(".", function(character)
		return string.format("%02x", string.byte(character))
	end)

	return `{hex:sub(1, 8)}-{hex:sub(9, 12)}-{hex:sub(13, 16)}-{hex:sub(17, 20)}-{hex:sub(21, 32)}`
end

return createId
