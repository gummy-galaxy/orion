local graph = require("@root/graph")
local refs = require("@root/refs")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item
type Link = types.Link

--- The repository a pull request lives in, so a bare `#12` in its text resolves.
export type Context = { owner: string, name: string, host: string? }
--- Something one card's text points at. `upstream` means the target comes first.
export type Mention = { target: Item, kind: string, upstream: boolean }
export type Linked = { from: string, to: string, kind: string }

type Token = { first: number, last: number, kind: string, key: string?, repo: string?, number: number?, host: string? }

-- Only these phrases make a mention blocking; anything else is a plain reference.
local UPSTREAM = { "stacked on", "depends on", "blocked by" }
local DOWNSTREAM = { "blocks" }
local JIRA = "%f[%w][A-Z][A-Z0-9]+%-%d+%f[^%w]"

local mentions = {}

local function str(value: any): string?
	return if type(value) == "string" then value else nil
end

local function fullRepo(doc: Doc, repo: string): string
	return (if repo:find("/", 1, true) then repo else `{doc.settings.githubOwner}/{repo}`):lower()
end

--- Calls `visit` with the bounds and captures of every match of `pattern` in `line`.
local function scan(line: string, pattern: string, visit: (number, number, ...string) -> ())
	local start = 1
	while true do
		local found = table.pack(line:find(pattern, start))
		local first, last = found[1], found[2]
		if type(first) ~= "number" or type(last) ~= "number" then
			return
		end
		visit(first, last, table.unpack(found, 3, found.n))
		start = last + 1
	end
end

local function tokens(line: string, context: Context?): { Token }
	local found: { Token } = {}
	local function add(token: Token)
		for _, other in found do
			if token.first <= other.last and other.first <= token.last then
				return
			end
		end
		table.insert(found, token)
	end
	scan(
		line,
		"https?://([%w%.%-]+)/([%w_.%-]+)/([%w_.%-]+)/(%a+)/(%d+)",
		function(first, last, host, owner, name, kind, number)
			if kind == "pull" or kind == "issues" then
				add({
					first = first,
					last = last,
					kind = "github",
					repo = string.lower(`{owner}/{name}`),
					number = tonumber(number),
					host = host:lower(),
				})
			end
		end
	)
	scan(line, "([%w_.%-]+)/([%w_.%-]+)#(%d+)", function(first, last, owner, name, number)
		add({
			first = first,
			last = last,
			kind = "github",
			repo = string.lower(`{owner}/{name}`),
			number = tonumber(number),
			host = if context then context.host else nil,
		})
	end)
	if context then
		scan(line, "#(%d+)", function(first, last, number)
			local before = if first > 1 then line:sub(first - 1, first - 1) else ""
			if not before:match("[%w_/&]") then
				add({
					first = first,
					last = last,
					kind = "github",
					repo = string.lower(`{context.owner}/{context.name}`),
					number = tonumber(number),
					host = context.host,
				})
			end
		end)
	end
	scan(line, JIRA, function(first, last)
		add({ first = first, last = last, kind = "jira", key = line:sub(first, last) })
	end)
	table.sort(found, function(a: Token, b: Token)
		return a.first < b.first
	end)
	return found
end

--- Whether a phrase ending at `phraseEnd` reaches the reference at `upTo`, allowing only a list of references between.
local function governs(line: string, phraseEnd: number, upTo: number, all: { Token }): boolean
	local between = line:sub(phraseEnd + 1, upTo - 1)
	for index = #all, 1, -1 do
		local token = all[index]
		if token.first > phraseEnd and token.last < upTo then
			between = between:sub(1, token.first - phraseEnd - 1) .. between:sub(token.last - phraseEnd + 1)
		end
	end
	between = between:lower():gsub("%f[%a]and%f[%A]", ""):gsub("[%s,:;&%*`%[%]%(%)]", "")
	return between == ""
end

local function phraseKind(line: string, token: Token, all: { Token }): (string, boolean)
	local lower = line:lower()
	local best: string?, bestEnd, upstream = nil, 0, false
	for _, list in { UPSTREAM, DOWNSTREAM } do
		for _, phrase in list do
			scan(lower, `%f[%a]{phrase}%f[%A]`, function(_, last)
				if last < token.first and last > bestEnd then
					best, bestEnd, upstream = phrase, last, list == UPSTREAM
				end
			end)
		end
	end
	if best and governs(line, bestEnd, token.first, all) then
		return "blocks", upstream
	end
	return "related", true
end

local function findJira(doc: Doc, key: string): Item?
	for _, item in doc.nodes do
		if item.type == "task" then
			for _, ref in refs.ofKind(item, "jira") do
				if str(ref.key) == key then
					return item
				end
			end
		end
	end
	return nil
end

local function findGithub(doc: Doc, repo: string, number: number, host: string?): Item?
	for _, item in doc.nodes do
		if item.type ~= "task" then
			continue
		end
		for _, ref in refs.list(item) do
			local ownRepo = str(ref.repo)
			if
				(ref.kind == "github-pr" or ref.kind == "github-issue")
				and ref.number == number
				and ownRepo
				and fullRepo(doc, ownRepo) == repo
				and (str(ref.host) or "github.com") == (host or "github.com")
			then
				return item
			end
		end
	end
	return nil
end

--- The first Jira key in a pull request's title, or failing that its branch: the ticket the work is for.
function mentions.ownKey(title: string, branch: string?): string?
	local key = title:match(JIRA)
	if key then
		return key
	end
	return if branch then branch:upper():match(JIRA) else nil
end

--- The card holding a Jira ticket, if one is on the canvas.
mentions.findJira = findJira

--- Cards that text points at directly, with the link each mention implies.
function mentions.scan(doc: Doc, text: string, context: Context?): { Mention }
	local out: { Mention } = {}
	for line in string.gmatch(`{text}\n`, "([^\n]*)\n") do
		local all = tokens(line, context)
		for _, token in all do
			local target = if token.kind == "jira"
				then findJira(doc, token.key :: string)
				else findGithub(doc, token.repo :: string, token.number :: number, token.host)
			if target then
				local kind, upstream = phraseKind(line, token, all)
				table.insert(out, { target = target, kind = kind, upstream = upstream })
			end
		end
	end
	return out
end

--- Links two cards unless they're already linked. A blocking mention upgrades a related one it made earlier.
function mentions.connect(doc: Doc, item: Item, target: Item, kind: string, upstream: boolean): Linked?
	if item.id == target.id or graph.isGroup(item) or graph.isGroup(target) then
		return nil
	end
	local from, to = if upstream then target.id else item.id, if upstream then item.id else target.id
	for index, link in doc.links do
		if (link.from == item.id and link.to == target.id) or (link.from == target.id and link.to == item.id) then
			if not (kind == "blocks" and link.kind == "related" and link.origin == "mention") then
				return nil
			end
			table.remove(doc.links, index)
			break
		end
	end
	graph.link(doc, from, to, kind).origin = "mention"
	return { from = from, to = to, kind = kind }
end

--- Links a card to everything its text mentions directly, returning the links it added.
function mentions.link(doc: Doc, item: Item, text: string, context: Context?): { Linked }
	local added: { Linked } = {}
	for _, mention in mentions.scan(doc, text, context) do
		local linked = mentions.connect(doc, item, mention.target, mention.kind, mention.upstream)
		if linked then
			table.insert(added, linked)
		end
	end
	return added
end

return table.freeze(mentions)
