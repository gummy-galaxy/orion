local json = require("@std/json")

local types = require("@root/types")

type Item = types.Item
type Source = types.Source
export type Ref = json.Object

-- A card's sources are typed references to the things it stands for. Tracking sources say what the work is,
-- implementation sources stack on top of them and drive live status, and context sources are links only.
local refs = {}

local ROLE: { [string]: string } = {
	jira = "tracking",
	["github-issue"] = "tracking",
	["github-pr"] = "implementation",
	hop = "implementation",
	["github-release"] = "context",
	slack = "context",
	url = "context",
}
local ROLE_ORDER = { tracking = 1, implementation = 2, context = 3 }
local LEGACY = { "repo", "pr", "host", "issue", "branch", "github", "jira", "activity" }
local REPO = "^[%w_.%-]+$"
local OWNER_REPO = "^([%w_.%-]+)/([%w_.%-]+)$"

refs.KINDS = { "github-pr", "github-issue", "github-release", "jira", "slack", "hop", "url" }

local function str(value: json.Value): string?
	return if type(value) == "string" and value ~= "" then value else nil
end

local function num(value: json.Value): number?
	return if type(value) == "number" then value else nil
end

function refs.role(ref: Ref): string
	return ROLE[str(ref.kind) or ""] or "context"
end

local function feedFamily(kind: string): string
	return if kind == "jira" then "jira" elseif kind == "hop" then "hop" else "github"
end

local function refFamily(kind: string): string
	return if kind == "jira" then "jira" elseif kind == "hop" then "hop" else "github"
end

local function new(fields: { [string]: json.Value }): Ref
	local ref = json.object({})
	for key, value in fields do
		ref[key] = value
	end
	return ref
end

local function copy(object: json.Object?, keys: { string }): json.Object?
	if not object then
		return nil
	end
	local out = json.object({})
	for _, key in keys do
		out[key] = object[key]
	end
	return out
end

local function hasLegacy(data: json.Object): boolean
	for _, key in LEGACY do
		if data[key] ~= nil then
			return true
		end
	end
	for _, entry in json.asArray(data.sources) or {} do
		if type(entry) == "string" then
			return true
		end
	end
	return false
end

--- The work kind a card's sources imply. Notes and gates keep their kind.
function refs.itemKind(item: Item): string
	local current = str(item.data.itemKind)
	if current == "note" or current == "gate" then
		return current
	end
	local placeholder = false
	for _, ref in refs.list(item) do
		if ref.kind == "github-pr" and num(ref.number) then
			return "pr"
		elseif ref.kind == "github-pr" or ref.kind == "github-issue" then
			placeholder = true
		end
	end
	return if placeholder then "placeholder" else "step"
end

local function refreshKind(item: Item)
	if item.type == "task" then
		item.data.itemKind = refs.itemKind(item)
	end
end

local function save(item: Item, list: { Ref })
	local array: json.Array = {}
	for _, ref in list do
		table.insert(array, ref)
	end
	item.data.sources = if #array > 0 then array else nil
	refreshKind(item)
end

--- Moves the fields cards used before typed sources into `data.sources`. `feeds` resolves which configured
--- source added each legacy reference; without it, feed ids are matched by their default names.
function refs.migrate(item: Item, feeds: { Source }?)
	local data = item.data
	if item.type ~= "task" or not hasLegacy(data) then
		return
	end
	local list: json.Array = {}
	local feedIds: { string } = {}
	for _, entry in json.asArray(data.sources) or {} do
		if type(entry) == "string" then
			table.insert(feedIds, entry)
		elseif json.asObject(entry) then
			table.insert(list, entry)
		end
	end
	local repo, host, branch = str(data.repo), str(data.host), str(data.branch)
	local jira = json.asObject(data.jira)
	if jira and str(jira.key) then
		local ref = new({ kind = "jira", key = jira.key })
		ref.url = str(jira.url)
		ref.state = copy(jira, { "status", "statusCategory", "type", "epicKey", "epicSummary", "updatedAt" })
		table.insert(list, ref)
	end
	if repo and num(data.issue) then
		local ref = new({ kind = "github-issue", repo = repo, number = data.issue })
		ref.host = host
		table.insert(list, ref)
	end
	local activity = json.asObject(data.activity)
	local pr = num(data.pr)
	if repo and pr then
		local ref = new({ kind = "github-pr", repo = repo, number = pr })
		ref.host, ref.branch, ref.state = host, branch, json.asObject(data.github)
		table.insert(list, ref)
	end
	local hop = repo and branch and (activity ~= nil or (not pr and not num(data.issue)))
	if hop then
		local ref = new({ kind = "hop", repo = repo :: string, branch = branch :: string })
		ref.host, ref.state = host, activity
		table.insert(list, ref)
	end
	if repo and not pr and not num(data.issue) and not hop then
		local ref = new({ kind = "github-pr", repo = repo })
		ref.host = host
		table.insert(list, ref)
	end
	local kinds: { [string]: string } = {}
	for _, feed in feeds or {} do
		kinds[feed.id] = feed.kind
	end
	for _, id in feedIds do
		local family =
			feedFamily(kinds[id] or (if id:match("^jira") then "jira" elseif id:match("^hop") then "hop" else "github"))
		for _, raw in list do
			local ref = json.asObject(raw)
			if ref and not ref.via and refFamily(str(ref.kind) or "") == family then
				ref.via = id
			end
		end
	end
	for _, key in LEGACY do
		data[key] = nil
	end
	data.sources = if #list > 0 then list else nil
	refreshKind(item)
end

--- The card's sources as stored, after carrying over any legacy fields.
function refs.list(item: Item): { Ref }
	refs.migrate(item, nil)
	local out: { Ref } = {}
	for _, raw in json.asArray(item.data.sources) or {} do
		local ref = json.asObject(raw)
		if ref and str(ref.kind) then
			table.insert(out, ref)
		end
	end
	return out
end

--- Tracking sources first, then implementation in the order they stacked, then context.
function refs.ordered(item: Item): { Ref }
	local list = refs.list(item)
	type Entry = { index: number, ref: Ref }
	local indexed: { Entry } = {}
	for index, ref in list do
		table.insert(indexed, { index = index, ref = ref })
	end
	table.sort(indexed, function(a: Entry, b: Entry)
		local left: number, right: number = ROLE_ORDER[refs.role(a.ref)], ROLE_ORDER[refs.role(b.ref)]
		return if left == right then a.index < b.index else left < right
	end)
	local out: { Ref } = {}
	for _, entry in indexed do
		table.insert(out, entry.ref)
	end
	return out
end

function refs.ofKind(item: Item, kind: string): { Ref }
	local out: { Ref } = {}
	for _, ref in refs.list(item) do
		if ref.kind == kind then
			table.insert(out, ref)
		end
	end
	return out
end

function refs.first(item: Item, kind: string): Ref?
	return refs.ofKind(item, kind)[1]
end

--- Pull requests that exist, as opposed to expected ones.
function refs.pulls(item: Item): { Ref }
	local out: { Ref } = {}
	for _, ref in refs.ofKind(item, "github-pr") do
		if num(ref.number) then
			table.insert(out, ref)
		end
	end
	return out
end

--- The pull request whose state the card shows: the topmost open one, else the topmost.
function refs.driver(item: Item): Ref?
	local pulls = refs.pulls(item)
	for index = #pulls, 1, -1 do
		local state = json.asObject(pulls[index].state)
		if state and state.state == "OPEN" then
			return pulls[index]
		end
	end
	return pulls[#pulls]
end

--- The first repository any GitHub or hop source names.
function refs.repo(item: Item): (string?, string?)
	for _, ref in refs.ordered(item) do
		local repo = str(ref.repo)
		if repo and ref.kind ~= "url" then
			return repo, str(ref.host)
		end
	end
	return nil, nil
end

function refs.branch(item: Item): string?
	for _, ref in refs.list(item) do
		local branch = str(ref.branch)
		if branch then
			return branch
		end
	end
	return nil
end

function refs.jira(item: Item): Ref?
	return refs.first(item, "jira")
end

function refs.activity(item: Item): json.Object?
	local hop = refs.first(item, "hop")
	return if hop then json.asObject(hop.state) else nil
end

local function lowerRepo(repo: string): string
	return repo:lower()
end

--- Identity, ignoring the snapshot and provenance. Expected pull requests share one identity per repository.
function refs.identity(ref: Ref): string
	local kind = str(ref.kind) or ""
	local host = (str(ref.host) or "github.com"):lower()
	if kind == "github-pr" or kind == "github-issue" then
		return `{kind}:{host}/{lowerRepo(str(ref.repo) or "")}#{num(ref.number) or ""}`
	elseif kind == "github-release" then
		return `{kind}:{host}/{lowerRepo(str(ref.repo) or "")}@{str(ref.tag) or ""}`
	elseif kind == "jira" then
		return `jira:{(str(ref.key) or ""):upper()}`
	elseif kind == "hop" then
		return `hop:{lowerRepo(str(ref.repo) or "")}:{str(ref.branch) or ""}`
	end
	return `{kind}:{str(ref.url) or ""}`
end

function refs.tag(ref: Ref): string
	local kind = str(ref.kind)
	local repo = str(ref.repo) or ""
	if kind == "github-pr" or kind == "github-issue" then
		local number = num(ref.number)
		return if number then `{repo}#{number}` else repo
	elseif kind == "github-release" then
		return `{repo}@{str(ref.tag) or ""}`
	elseif kind == "jira" then
		return str(ref.key) or "jira"
	elseif kind == "hop" then
		return repo
	elseif kind == "slack" then
		return str(ref.label) or "Slack"
	end
	local url = str(ref.url) or ""
	return str(ref.label) or url:match("^https?://([^/]+)") or url
end

--- The card's tag: its tracking source when it has one, else what implements it, else context.
function refs.itemTag(item: Item): string?
	local first = refs.ordered(item)[1]
	return if first then refs.tag(first) else nil
end

local function fullRepo(repo: string, owner: string): string
	return if repo:find("/", 1, true) then repo else `{owner}/{repo}`
end

function refs.url(ref: Ref, owner: string): string?
	local kind = str(ref.kind)
	local host = str(ref.host) or "github.com"
	local repo = str(ref.repo)
	if kind == "github-pr" then
		local state = json.asObject(ref.state)
		local recorded = if state then str(state.url) else nil
		if recorded then
			return recorded
		end
		return if repo and num(ref.number) then `https://{host}/{fullRepo(repo, owner)}/pull/{ref.number}` else nil
	elseif kind == "github-issue" then
		return if repo then `https://{host}/{fullRepo(repo, owner)}/issues/{ref.number}` else nil
	elseif kind == "github-release" then
		local state = json.asObject(ref.state)
		local recorded = if state then str(state.url) else nil
		local tag = (str(ref.tag) or ""):gsub("[^%w%-%._~]", function(c)
			return string.format("%%%02X", string.byte(c))
		end)
		return recorded or (if repo then `https://{host}/{fullRepo(repo, owner)}/releases/tag/{tag}` else nil)
	elseif kind == "jira" then
		return str(ref.url)
	elseif kind == "hop" then
		return nil
	end
	return str(ref.url)
end

local function decode(text: string): string
	return (text:gsub("%%(%x%x)", function(hex)
		return string.char(tonumber(hex, 16) :: number)
	end))
end

local function shortRepo(owner: string, name: string, defaultOwner: string): string
	return if owner:lower() == defaultOwner:lower() then name else `{owner}/{name}`
end

local function repoPart(text: string, defaultOwner: string): string
	local owner, name = text:match(OWNER_REPO)
	if owner and name then
		return shortRepo(owner, name, defaultOwner)
	end
	assert(text:match(REPO), `invalid repository {text}`)
	return text
end

local function fromUrl(url: string, defaultOwner: string): Ref
	local host, path = url:match("^https://([^/@]+)(/[^?#]*)")
	assert(host and path, `{url} isn't an HTTPS URL`)
	host = host:lower()
	local hostField = if host == "github.com" then nil else host
	local owner, name, number = path:match("^/([^/]+)/([^/]+)/pull/(%d+)")
	if owner and name and number then
		local ref = new({ kind = "github-pr", repo = shortRepo(owner, name, defaultOwner), number = tonumber(number) })
		ref.host = hostField
		return ref
	end
	owner, name, number = path:match("^/([^/]+)/([^/]+)/issues/(%d+)")
	if owner and name and number then
		local ref =
			new({ kind = "github-issue", repo = shortRepo(owner, name, defaultOwner), number = tonumber(number) })
		ref.host = hostField
		return ref
	end
	local tag: string?
	owner, name, tag = path:match("^/([^/]+)/([^/]+)/releases/tag/(.+)$")
	if owner and name and tag then
		local ref = new({ kind = "github-release", repo = shortRepo(owner, name, defaultOwner), tag = decode(tag) })
		ref.host = hostField
		return ref
	end
	local key = path:match("/browse/([A-Za-z][A-Za-z0-9]*%-%d+)$")
	if key then
		return new({ kind = "jira", key = key:upper(), url = url })
	end
	if host == "slack.com" or host:match("%.slack%.com$") then
		return new({ kind = "slack", url = url })
	end
	return new({ kind = "url", url = url })
end

--- Reads a source from `kind` and `text`, or from a URL alone. GitHub repositories are "name" under the
--- default owner or "owner/name"; pull requests and issues add "#number", releases "@tag", and hop ":branch".
function refs.parse(kind: string?, text: string, defaultOwner: string): Ref
	assert(text ~= "", "missing source")
	assert(kind == nil or ROLE[kind], `source kind must be one of {table.concat(refs.KINDS, ", ")}`)
	if text:match("^https?://") then
		assert(
			text:match("^https://") and not text:match("^https://[^/]*@"),
			"source URLs need HTTPS without credentials"
		)
		local ref = fromUrl(text, defaultOwner)
		if kind == "slack" or kind == "url" then
			return new({ kind = kind, url = text })
		end
		assert(kind == nil or ref.kind == kind, `{text} isn't a {kind} URL`)
		return ref
	end
	assert(kind, "pass a source kind, or a URL")
	if kind == "github-pr" or kind == "github-issue" then
		local repo, number = text:match("^(.-)#(%d+)$")
		if not repo then
			assert(kind == "github-pr", "issues need a number, as repo#123")
			return new({ kind = kind, repo = repoPart(text, defaultOwner) })
		end
		return new({ kind = kind, repo = repoPart(repo, defaultOwner), number = tonumber(number) })
	elseif kind == "github-release" then
		local repo, tag = text:match("^([^@]+)@(.+)$")
		assert(repo and tag, "releases look like repo@tag")
		return new({ kind = kind, repo = repoPart(repo, defaultOwner), tag = tag })
	elseif kind == "jira" then
		assert(text:match("^[A-Za-z][A-Za-z0-9]*%-%d+$"), "Jira sources look like KEY-123")
		return new({ kind = kind, key = text:upper() })
	elseif kind == "hop" then
		local repo, branch = text:match("^([^:]+):(.+)$")
		assert(repo and branch, "hop sources look like repo:branch")
		return new({ kind = kind, repo = repoPart(repo, defaultOwner), branch = branch })
	end
	error(`{kind} sources need a URL`)
end

--- `kind:text` or a URL, as `orion add --source` takes it.
function refs.parseSpec(spec: string, defaultOwner: string): Ref
	if spec:match("^https?://") then
		return refs.parse(nil, spec, defaultOwner)
	end
	local kind, text = spec:match("^([%w%-]+):(.+)$")
	assert(
		kind and text and ROLE[kind],
		`sources look like kind:value or a URL, with kind one of {table.concat(refs.KINDS, ", ")}`
	)
	return refs.parse(kind, text, defaultOwner)
end

--- Adds a source, or refreshes the identity fields of one already there. A pull request with a number fills
--- in an expected pull request for the same repository.
function refs.attach(item: Item, ref: Ref): Ref
	assert(item.type == "task" and str(item.data.itemKind) ~= "note", "only work items take sources")
	local list = refs.list(item)
	local identity = refs.identity(ref)
	local target: Ref? = nil
	for _, existing in list do
		if refs.identity(existing) == identity then
			target = existing
			break
		end
	end
	if not target and ref.kind == "github-pr" and num(ref.number) then
		local expected = new({ kind = "github-pr", repo = ref.repo })
		expected.host = ref.host
		for _, existing in list do
			if refs.identity(existing) == refs.identity(expected) then
				target = existing
				break
			end
		end
	end
	if target then
		for key, value in ref do
			if key ~= "state" then
				target[key] = value
			end
		end
	else
		table.insert(list, ref)
		target = ref
	end
	save(item, list)
	return target :: Ref
end

function refs.detach(item: Item, ref: Ref): Ref
	local list = refs.list(item)
	local identity = refs.identity(ref)
	for index, existing in list do
		if refs.identity(existing) == identity then
			table.remove(list, index)
			save(item, list)
			return existing
		end
	end
	error(`{refs.tag(ref)} isn't a source of this item`)
end

--- Applies the older `--repo` and `--pr` options to the card's first pull request source.
function refs.setPull(item: Item, repo: string?, pr: number?)
	local list = refs.list(item)
	local pull: Ref? = refs.first(item, "github-pr")
	if repo == "" then
		if pull then
			table.remove(list, table.find(list, pull) :: number)
		end
		save(item, list)
		return
	end
	if repo then
		if pull then
			if pull.repo ~= repo then
				pull.state = nil
			end
			pull.repo = repo
		else
			pull = new({ kind = "github-pr", repo = repo })
			table.insert(list, pull :: Ref)
		end
	end
	if pr then
		assert(pull, "a pull request number needs a repository; pass --repo too")
		local target = pull :: Ref
		if target.number ~= pr then
			target.state = nil
		end
		target.number = pr
	end
	save(item, list)
end

--- Records provenance on a source a feed brought in.
function refs.via(ref: Ref, feed: string)
	if ref.via == nil then
		ref.via = feed
	end
end

function refs.describe(ref: Ref): string
	local via = str(ref.via)
	return `{str(ref.kind) or "?"} {refs.tag(ref)}{if via then ` (via {via})` else ""}`
end

return table.freeze(refs)
