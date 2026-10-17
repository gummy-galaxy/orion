local assetExists = require("@root/media/assetExists")
local isAssetId = require("@root/media/isAssetId")

-- A cover or background that names an image must name one this workspace holds. Colors and token names pass.
return function(dir: string, value: string?)
	if value and value ~= "" and isAssetId(value) then
		assert(assetExists(dir, value), `no image {value} in this workspace; add it with orion media insert`)
	end
end
