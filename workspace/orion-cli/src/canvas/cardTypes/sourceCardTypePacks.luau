local cardTypes = require("@root/canvas/cardTypes/types")

type CardType = cardTypes.CardType

-- The card types each source kind declares, by kind, which register beside the
-- ones Orion ships. A source whose refs only attach shipped types, as GitHub,
-- Jira, and hop do, needs no entry. Packs stay apart from the adapters, so
-- reading types never loads a source's code.
local sourceCardTypePacks: { [string]: { CardType } } = {}

return table.freeze(sourceCardTypePacks)
