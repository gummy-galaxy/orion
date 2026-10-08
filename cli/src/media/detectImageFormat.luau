local validateImageSize = require("@root/media/validateImageSize")

return function(bytes: string): (string, string)
	validateImageSize(#bytes)
	if bytes:sub(1, 8) == string.char(137, 80, 78, 71, 13, 10, 26, 10) then
		return "png", "image/png"
	elseif bytes:sub(1, 3) == string.char(255, 216, 255) then
		return "jpg", "image/jpeg"
	elseif bytes:sub(1, 6) == "GIF87a" or bytes:sub(1, 6) == "GIF89a" then
		return "gif", "image/gif"
	elseif bytes:sub(1, 4) == "RIFF" and bytes:sub(9, 12) == "WEBP" then
		return "webp", "image/webp"
	end
	error("image must be PNG, JPEG, GIF, or WebP")
end
