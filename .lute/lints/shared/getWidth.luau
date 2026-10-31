local TAB_WIDTH = 4

-- Counts the columns `text` takes up, with a tab reaching the next multiple of
-- four.
local function getWidth(text: string): number
	local width = 0

	for index = 1, #text do
		if text:sub(index, index) == "\t" then
			width += TAB_WIDTH - width % TAB_WIDTH
		else
			width += 1
		end
	end

	return width
end

return getWidth
