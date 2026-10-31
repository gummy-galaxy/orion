local attachRef = require("@root/canvas/refs/attachRef")
local findRef = require("@root/canvas/refs/findRef")
local getItem = require("@root/canvas/items/getItem")
local getStringField = require("@root/common/getStringField")
local isGroup = require("@root/canvas/groups/isGroup")
local refreshItemKind = require("@root/canvas/items/refreshItemKind")
local removeRef = require("@root/canvas/refs/removeRef")
local resolveRef = require("@root/sources/resolveRef")
local types = require("@root/types")

type Doc = types.Doc

-- Points a card at a pull request in its repository, resolved through the
-- GitHub adapter, or takes its pull request off when `number` is nil. A pull
-- request the card already carries keeps the facts its source filled in.
local function setPullRequest(doc: Doc, id: string, number: number?)
	local item = getItem(doc, id)
	assert(not isGroup(item), "groups don't take refs; attach it to an item")

	if number == nil then
		removeRef(item, "pull")
		refreshItemKind(item)
		return
	end

	assert(number >= 1 and number == math.floor(number), "pr must be a pull request number")

	local repo = getStringField(item.data.repo)
	assert(repo, `"{id}" needs a repo before it takes a pull request`)

	local resolved = resolveRef(`https://github.com/{repo}/pull/{number}`, doc.settings.sources)

	if findRef(item, "pull", resolved.ref.key) == nil then
		removeRef(item, "pull")
		attachRef(doc, id, resolved)
	end
end

return setPullRequest
