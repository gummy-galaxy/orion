local checkBackground = require("@root/style/checkBackground")
local checkStyleAssets = require("@root/style/checkStyleAssets")
local isAssetId = require("@root/media/isAssetId")
local types = require("@root/types")

type Doc = types.Doc

export type CanvasStyleChange = {
	cover: string?,
	background: string?,
}

-- Sets the canvas's cover and background. A nil value leaves that setting alone, and an empty string clears it.
return function(doc: Doc, dir: string, change: CanvasStyleChange)
	if change.cover and change.cover ~= "" then
		assert(isAssetId(change.cover), "cover must be an image asset id, such as the asset from orion media insert")
	end

	if change.background and change.background ~= "" then
		checkBackground(change.background)
	end

	checkStyleAssets(dir, change.cover)
	checkStyleAssets(dir, change.background)

	if change.cover then
		doc.settings.cover = if change.cover == "" then nil else change.cover
	end

	if change.background then
		doc.settings.background = if change.background == "" then nil else change.background
	end
end
