local attachRef = require("@root/graph/attachRef")
local findRef = require("@root/refs/findRef")
local getItem = require("@root/graph/getItem")
local getStringField = require("@root/getStringField")
local isGroup = require("@root/graph/isGroup")
local refreshItemKind = require("@root/graph/refreshItemKind")
local removeRef = require("@root/refs/removeRef")
local resolveRef = require("@root/adapters/resolveRef")
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
