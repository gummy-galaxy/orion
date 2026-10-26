-- The kind a card takes from its repository, pull request, and any kind it was
-- given. Gates and components keep theirs.
local function chooseItemKind(repo: string?, pr: number?, kind: string?): string
	if kind == "gate" or kind == "component" then
		return kind
	end

	if repo and pr then
		return "pr"
	end

	return if repo then "placeholder" else "step"
end

return chooseItemKind
