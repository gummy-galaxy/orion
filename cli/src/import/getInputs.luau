-- Collects the refs to import: the arguments, then each line of stdin when it was read. Blank lines are skipped.
local function getInputs(arguments: { string }, stdin: string?): { string }
	local inputs: { string } = {}

	local function add(text: string)
		local trimmed = assert(text:match("^%s*(.-)%s*$"))

		if trimmed ~= "" then
			table.insert(inputs, trimmed)
		end
	end

	for _, argument in arguments do
		add(argument)
	end

	for line in (stdin or ""):gmatch("[^\r\n]+") do
		add(line)
	end

	return inputs
end

return getInputs
