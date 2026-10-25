local function getOne(options: { [string]: { string } }, key: string): string?
	local values = options[key]
	assert(not values or #values == 1, `--{key} may be given once`)
	return if values then values[1] else nil
end

return getOne
