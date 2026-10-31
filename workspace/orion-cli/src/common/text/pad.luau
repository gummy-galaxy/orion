return function(text: string, width: number): string
	if #text >= width then
		return text:sub(1, width - 1) .. "…"
	end
	return text .. string.rep(" ", width - #text)
end
