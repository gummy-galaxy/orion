local function isListed(repos: { string }?, name: string): boolean
	if not repos then
		return false
	end

	for _, repo in repos do
		if repo:lower() == name:lower() then
			return true
		end
	end

	return false
end

return isListed
