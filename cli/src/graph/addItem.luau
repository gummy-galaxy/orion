local json = require("@std/json")

local checkFields = require("@root/graph/checkFields")
local chooseItemKind = require("@root/graph/chooseItemKind")
local findPlacement = require("@root/graph/findPlacement")
local getGithubKey = require("@root/refs/getGithubKey")
local getNeighborGroup = require("@root/graph/getNeighborGroup")
local getUniqueId = require("@root/graph/getUniqueId")
local graphTypes = require("@root/graph/types")
local linkNeighbors = require("@root/graph/linkNeighbors")
local setLook = require("@root/graph/setLook")
local setRef = require("@root/refs/setRef")
local slugify = require("@root/slugify")
local types = require("@root/types")

type AddOptions = graphTypes.AddOptions
type Doc = types.Doc
type Item = types.Item

-- Adds a work item beside the items it links to, after `after` and before `before` when given.
local function addItem(doc: Doc, label: string, options: AddOptions): Item
	assert(label ~= "", "an item needs a label")
	checkFields(options)
	assert(options.shape == nil or options.kind == nil or options.kind == "component", "only components take a shape")
	assert(options.pr == nil or options.repo ~= nil, "pr needs a repository as owner/name")

	local group = getNeighborGroup(doc, options.group, options.after, options.before)
	local base = if options.repo and options.pr
		then `{slugify(options.repo :: string)}-{options.pr}`
		else slugify(label)
	local data: json.Object = json.object({
		kind = "task",
		label = label,
		-- A shape only fits a component, so giving one makes the item a component.
		itemKind = chooseItemKind(options.repo, options.pr, if options.shape then "component" else options.kind),
		status = options.status or "todo",
	})
	data.repo = options.repo
	data.note = options.note
	data.who = if options.who == "" then nil else options.who
	local item: Item = {
		id = getUniqueId(doc, base),
		type = "task",
		position = { x = 0, y = 0 },
		parentId = group,
		data = data,
	}

	if options.pr and options.repo then
		local owner, name = options.repo:match("^([^/]+)/([^/]+)$")
		setRef(item, {
			source = "github",
			kind = "pull",
			key = getGithubKey(assert(owner), assert(name), `#{options.pr}`),
			url = `https://github.com/{options.repo}/pull/{options.pr}`,
		})
	end

	setLook(item, options)
	table.insert(doc.nodes, item)
	linkNeighbors(doc, item.id, options.after, options.before)
	item.position = findPlacement(doc, item)
	return item
end

return addItem
