local function checkOptions(kind: string, options: { [string]: { string } }, allowed: { [string]: boolean })
	for key in options do
		assert(allowed[key] or key == "id", `--{key} does not apply to {kind}`)
	end
end

return checkOptions
