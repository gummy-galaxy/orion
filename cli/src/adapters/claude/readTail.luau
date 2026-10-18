local fs = require("@std/fs")

-- The last `bytes` of a file, starting at a whole line. Transcripts grow to tens of megabytes, and everything a card
-- needs is near the end.
local function readTail(filePath: string, bytes: number): string
	local size = fs.metadata(filePath).size
	local offset = math.max(0, size - bytes)
	local count = size - offset

	if count == 0 then
		return ""
	end

	local file = fs.open(filePath, "r")
	local contents = buffer.create(count)
	local read = fs.readIntoBuffer(file, contents, offset, count)
	fs.close(file)
	local text = buffer.readstring(contents, 0, read)

	if offset > 0 then
		local lineEnd = text:find("\n", 1, true)
		text = if lineEnd then text:sub(lineEnd + 1) else ""
	end

	return text
end

return readTail
