local json = require("@std/json")

local types = require("@root/types")

type Item = types.Item
type Link = types.Link

-- One edit to the document. `op` names the edit; the other fields are what that
-- edit reads, and each edit checks its own. A field an edit doesn't read is
-- ignored.
export type Operation = {
	op: string,
	id: string?,
	from: string?,
	to: string?,
	kind: string?,
	group: string?,
	items: { string }?,
	label: string?,
	x: number?,
	y: number?,
	reconnect: boolean?,
	fields: { [string]: string | number }?,
	-- addCard, addNote, addImage, and addGroup: the kind of item to add, set by
	-- the operation's name.
	nodeType: string?,
	-- addCard, addNote, addImage, addGroup, and resize: the stored size.
	-- `clear` on a resize drops the stored size instead.
	width: number?,
	height: number?,
	clear: boolean?,
	-- The add operations and setData: the item's data, as the app keeps it.
	data: json.Object?,
	-- setStickers and setStickerLoadout: the whole list, as the app keeps it.
	stickers: json.Array?,
	stickerLoadout: json.Array?,
}

-- Undoes one operation: each item and link it changed, as it was before. Nodes
-- and links put back keep their index so the document's order survives a round
-- trip. A sticker list is put back only when it changed.
export type Restore = {
	nodes: { { index: number, item: Item } },
	removedNodes: { string },
	links: { { index: number, link: Link } },
	removedLinks: { { from: string, to: string } },
	stickers: { value: json.Array? }?,
	stickerLoadout: { value: json.Array? }?,
}

-- Every node and link with its index, so a change can be compared and restored.
export type Snapshot = {
	nodes: { [string]: { index: number, item: Item } },
	links: { [string]: { index: number, link: Link } },
	stickers: json.Array?,
	stickerLoadout: json.Array?,
}

return {}
