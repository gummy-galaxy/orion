local function isValidWorkspace(name: string): boolean
	return name ~= "" and name:match("^[a-z0-9%-]+$") ~= nil
end

return isValidWorkspace
