local json = require("@std/json")

local handleMessage = require("@root/cli/mcp/server/handleMessage")
local mcpTypes = require("@root/cli/mcp/types")

type Run = mcpTypes.Run

-- Reads stdin in chunks that may hold several messages or part of one, and stops at end of input.
local function serve(read: () -> string, write: (string) -> (), run: Run)
	local pending = ""

	while true do
		local ok, chunk = pcall(read)

		if not ok or chunk == "" then
			return
		end

		pending ..= chunk

		while true do
			local newline = string.find(pending, "\n", 1, true)

			if newline == nil then
				break
			end

			local line = string.gsub(string.sub(pending, 1, newline - 1), "\r$", "")
			pending = string.sub(pending, newline + 1)

			if string.find(line, "%S") then
				local response = handleMessage(line, run)

				if response then
					write(json.serialize(response) .. "\n")
				end
			end
		end
	end
end

return serve
