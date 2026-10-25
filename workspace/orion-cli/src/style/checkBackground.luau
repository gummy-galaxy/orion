local isAssetId = require("@root/media/isAssetId")

local HEX_DIGIT_COUNTS: { [number]: boolean } = { [3] = true, [4] = true, [6] = true, [8] = true }

-- A background is a hex color, a color token such as card.background, or an image asset id.
return function(value: string)
	if isAssetId(value) then
		return
	end

	if value:sub(1, 1) == "#" then
		assert(
			value:match("^#%x+$") and HEX_DIGIT_COUNTS[#value - 1],
			`background color must be #rgb, #rgba, #rrggbb, or #rrggbbaa, not "{value}"`
		)
		return
	end

	assert(
		value:match("^[a-z][a-z%-]*%.[a-z0-9%.%-]+$"),
		`background must be a hex color, a token name such as card.background, or an image asset id, not "{value}"`
	)
end
