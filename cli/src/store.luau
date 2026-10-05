local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")
local process = require("@std/process")
local task = require("@std/task")

local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item
type Link = types.Link

-- The app's dev server takes the same lock, so neither side overwrites the other.
local FILE = "orion.json"
local LOCK = "orion.lock"
local LOCK_TIMEOUT_SECONDS = 5
local STALE_LOCK_SECONDS = 30
local DEFAULT_OWNER = "flipbook-labs"
local WORKSPACES = "workspaces.json"

export type Workspace = { name: string, label: string }
export type WorkspaceList = { active: string, workspaces: { Workspace } }

local store = {}

local function str(value: json.Value): string?
	return if type(value) == "string" then value else nil
end

function store.defaultDir(): string
	local configured = process.env.ORION_DATA_DIR
	if configured and configured ~= "" then
		return tostring(path.resolve(configured))
	end
	return tostring(path.join(process.homedir(), "Library", "Application Support", "Orion"))
end

function store.validWorkspace(name: string): boolean
	return name ~= "" and name:match("^[a-z0-9%-]+$") ~= nil
end

function store.workspaceDir(root: string, name: string): string
	assert(store.validWorkspace(name), `invalid workspace name: {name}`)
	return if name == "default" then root else tostring(path.join(root, "workspaces", name))
end

function store.workspaces(root: string): WorkspaceList
	local file = tostring(path.join(root, WORKSPACES))
	local result: WorkspaceList = { active = "default", workspaces = { { name = "default", label = "Default" } } }
	if not fs.exists(file) then
		return result
	end
	local raw = json.asObject(json.deserialize(fs.readFileToString(file)) :: json.Value)
	assert(raw, `invalid workspace list at {file}`)
	local names: { [string]: boolean } = { default = true }
	for _, entry in json.asArray(raw.workspaces) or {} do
		local item = json.asObject(entry)
		local name = if item then str(item.name) else nil
		local label = if item then str(item.label) else nil
		assert(name and store.validWorkspace(name) and label and label ~= "", `invalid workspace in {file}`)
		if name == "default" then
			result.workspaces[1].label = label
		elseif not names[name] then
			table.insert(result.workspaces, { name = name, label = label })
			names[name] = true
		end
	end
	local active = str(raw.active) or "default"
	assert(names[active], `unknown workspace: {active}`)
	result.active = active
	return result
end

local workspaceWriteSequence = 0

local function writeWorkspaces(root: string, list: WorkspaceList)
	if not fs.exists(root) then
		fs.createDirectory(root, { makeParents = true })
	end
	local entries: json.Array = {}
	for _, workspace in list.workspaces do
		table.insert(entries, json.object({ name = workspace.name, label = workspace.label }))
	end
	local file = tostring(path.join(root, WORKSPACES))
	workspaceWriteSequence += 1
	local temporary = `{file}.tmp.{process.pid()}.{workspaceWriteSequence}`
	fs.writeStringToFile(temporary, json.serialize(json.object({ active = list.active, workspaces = entries }), true))
	fs.move(temporary, file)
end

function store.activeWorkspace(root: string, requested: string?): string
	local list = store.workspaces(root)
	local configured = process.env.ORION_WORKSPACE
	local name = requested or (if configured ~= "" then configured else nil) or list.active
	assert(store.validWorkspace(name), `invalid workspace name: {name}`)
	for _, workspace in list.workspaces do
		if workspace.name == name then
			return name
		end
	end
	error(`unknown workspace: {name}`)
end

function store.createWorkspace(root: string, name: string, label: string?, owner: string?): WorkspaceList
	assert(store.validWorkspace(name), `invalid workspace name: {name}`)
	assert(label == nil or label:match("%S"), "label must be nonempty")
	assert(owner == nil or owner ~= "", "owner must be nonempty")
	local list = store.workspaces(root)
	for _, workspace in list.workspaces do
		assert(workspace.name ~= name, `workspace already exists: {name}`)
	end
	local dir = store.workspaceDir(root, name)
	assert(not fs.exists(dir), `workspace folder already exists: {dir}`)
	store.write(dir, {
		version = 1,
		revision = 0,
		settings = { githubOwner = owner or DEFAULT_OWNER },
		nodes = {},
		links = {},
	})
	table.insert(list.workspaces, { name = name, label = label or name })
	writeWorkspaces(root, list)
	return list
end

function store.useWorkspace(root: string, name: string): WorkspaceList
	local list = store.workspaces(root)
	assert(store.validWorkspace(name), `invalid workspace name: {name}`)
	local known = false
	for _, workspace in list.workspaces do
		known = known or workspace.name == name
	end
	assert(known, `unknown workspace: {name}`)
	list.active = name
	writeWorkspaces(root, list)
	return list
end

function store.filePath(dir: string): string
	return tostring(path.join(dir, FILE))
end

local function num(value: json.Value): number?
	return if type(value) == "number" then value else nil
end

function store.decode(text: string): Doc
	local root = json.asObject(json.deserialize(text) :: json.Value)
	assert(root, "Orion data must be a JSON object")

	local nodes: { Item } = {}
	for _, raw in json.asArray(root.nodes) or {} do
		local object = json.asObject(raw)
		local id = if object then str(object.id) else nil
		local kind = if object then str(object.type) else nil
		if object and id and kind then
			local position = json.asObject(object.position) or json.object({})
			table.insert(nodes, {
				id = id,
				type = kind,
				position = { x = num(position.x) or 0, y = num(position.y) or 0 },
				parentId = str(object.parentId),
				width = num(object.width),
				height = num(object.height),
				data = json.asObject(object.data) or json.object({}),
			})
		end
	end

	local links: { Link } = {}
	for _, raw in json.asArray(root.links) or {} do
		local object = json.asObject(raw)
		local from = if object then str(object.from) else nil
		local to = if object then str(object.to) else nil
		if object and from and to then
			table.insert(links, {
				id = str(object.id) or `{from}>{to}`,
				from = from,
				to = to,
				kind = str(object.kind) or "blocks",
			})
		end
	end

	local settings = json.asObject(root.settings) or json.object({})
	return {
		version = num(root.version) or 1,
		revision = num(root.revision) or 0,
		settings = { githubOwner = str(settings.githubOwner) or DEFAULT_OWNER },
		nodes = nodes,
		links = links,
		github = json.asObject(root.github),
		raw = json.object(root),
	}
end

function store.encode(doc: Doc): string
	local nodes: json.Array = {}
	for _, item in doc.nodes do
		local object: json.Object = json.object({
			id = item.id,
			type = item.type,
			position = json.object({ x = item.position.x, y = item.position.y }),
			data = json.object(item.data),
		})
		object.parentId = item.parentId
		object.width = item.width
		object.height = item.height
		table.insert(nodes, object)
	end
	local links: json.Array = {}
	for _, link in doc.links do
		table.insert(links, json.object({ id = link.id, from = link.from, to = link.to, kind = link.kind }))
	end
	local root = json.object(doc.raw or {})
	root.version = doc.version
	root.revision = doc.revision
	root.settings = json.object({ githubOwner = doc.settings.githubOwner })
	root.nodes = nodes
	root.links = links
	root.github = doc.github
	return json.serialize(root, true)
end

function store.read(dir: string): Doc?
	local file = store.filePath(dir)
	if not fs.exists(file) then
		return nil
	end
	return store.decode(fs.readFileToString(file))
end

-- Fails with a pointer to the app when there is nothing to work with yet.
function store.load(dir: string): Doc
	local doc = store.read(dir)
	assert(doc, `no Orion data at {store.filePath(dir)}. Open the Orion app once to create it.`)
	return doc
end

local function release(lockPath: string)
	pcall(function()
		fs.removeDirectory(lockPath, { recursive = true })
	end)
end

local function acquire(dir: string): string
	local lockPath = tostring(path.join(dir, LOCK))
	local ownerPath = path.join(lockPath, "owner")
	local deadline = os.time() + LOCK_TIMEOUT_SECONDS
	while true do
		if process.run({ "mkdir", lockPath }).ok then
			fs.writeStringToFile(ownerPath, `{process.pid()} {os.time()}`)
			return lockPath
		end
		-- Reclaim a lock left behind by a writer that crashed.
		local ok, owner = pcall(fs.readFileToString, ownerPath)
		local stamp = if ok then tonumber(owner:match("%s(%d+)")) else nil
		if stamp and os.time() - stamp > STALE_LOCK_SECONDS then
			release(lockPath)
			continue
		end
		assert(os.time() < deadline, `timed out waiting for {lockPath}`)
		task.wait(0.05)
	end
end

local writeSequence = 0

local function atomicWrite(file: string, contents: string)
	writeSequence += 1
	local temporary = `{file}.tmp.{process.pid()}.{writeSequence}`
	fs.writeStringToFile(temporary, contents)
	fs.move(temporary, file)
end

-- Reads the latest data under the lock, applies `mutate`, and writes the next revision.
function store.transaction(dir: string, mutate: (Doc) -> ()): Doc
	if not fs.exists(dir) then
		fs.createDirectory(dir, { makeParents = true })
	end
	local lockPath = acquire(dir)
	local ok, result = pcall(function(): Doc
		local doc = store.load(dir)
		mutate(doc)
		doc.revision += 1
		atomicWrite(store.filePath(dir), store.encode(doc))
		return doc
	end)
	release(lockPath)
	if not ok then
		error(result, 0)
	end
	return result :: Doc
end

-- Writes a whole document, used to seed data and in tests.
function store.write(dir: string, doc: Doc)
	if not fs.exists(dir) then
		fs.createDirectory(dir, { makeParents = true })
	end
	local lockPath = acquire(dir)
	local ok, err = pcall(atomicWrite, store.filePath(dir), store.encode(doc))
	release(lockPath)
	if not ok then
		error(err, 0)
	end
end

return table.freeze(store)
