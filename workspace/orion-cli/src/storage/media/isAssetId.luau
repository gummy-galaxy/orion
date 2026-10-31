local IMAGE_EXTENSIONS: { [string]: boolean } = { png = true, jpg = true, gif = true, webp = true }

-- Asset ids name a file in a workspace's assets folder, such as image-logo.png.
return function(value: string): boolean
	local stem, extension = value:match("^([a-z0-9%-]+)%.(%a+)$")

	if not stem or not extension then
		return false
	end

	return IMAGE_EXTENSIONS[extension] == true
end
