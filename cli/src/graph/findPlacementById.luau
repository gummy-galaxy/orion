local types = require("@root/types")

type Doc = types.Doc
type Placement = types.Placement

-- An extra placement by its id, with its index in `doc.placements`. A node's own record isn't one of these.
local function findPlacementById(doc: Doc, id: string): (Placement?, number?)
	for index, placement in doc.placements or {} do
		if placement.id == id then
			return placement, index
		end
	end

	return nil, nil
end

return findPlacementById
