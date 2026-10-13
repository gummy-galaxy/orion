local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")
local process = require("@std/process")
local task = require("@std/task")

local deriveWorkspaceName = require("@root/deriveWorkspaceName")
local fileNames = require("@root/fileNames")
local getDefaultDataDir = require("@root/platform/getDefaultDataDir")
local graph = require("@root/graph")
local migrateItem = require("@root/refs/migrateItem")
local types = require("@root/types")

type Doc = types.Doc
type Focus = types.Focus
type Item = types.Item
type Link = types.Link
type Source = types.Source

local DAY_SECONDS = 24 * 60 * 60
local DAILY_DAYS = 30
local LOCK_TIMEOUT_SECONDS = 5
local STALE_LOCK_SECONDS = 30

export type Workspace = { name: string, label: string }
export type WorkspaceList = { active: string, workspaces: { Workspace }, archived: { Workspace } }
export type Backup = { revision: number, time: string, size: number, file: string }

local store = {}

local function asString(value: json.Value): string?
	return if type(value) == "string" then value else nil
end

function store.defaultDir(): string
	local configured = process.env.ORION_DATA_DIR

	if configured and configured ~= "" then
		return tostring(path.resolve(configured))
	end

	return tostring(getDefaultDataDir())
end

function store.isValidWorkspace(name: string): boolean
	return name ~= "" and name:match("^[a-z0-9%-]+$") ~= nil
end

function store.getWorkspaceDir(root: string, name: string): string
	assert(store.isValidWorkspace(name), `invalid workspace name: {name}`)
	return if name == "default" then root else tostring(path.join(root, "workspaces", name))
end

function store.getWorkspaces(root: string): WorkspaceList
	local file = tostring(path.join(root, fileNames.workspaces))
	local result: WorkspaceList =
		{ active = "default", workspaces = { { name = "default", label = "Default" } }, archived = {} }

	if not fs.exists(file) then
		return result
	end

	local raw = json.asObject(json.deserialize(fs.readFileToString(file)) :: json.Value)
	assert(raw, `invalid workspace list at {file}`)
	local names: { [string]: boolean } = { default = true }

	for _, entry in json.asArray(raw.workspaces) or {} do
		local item = json.asObject(entry)
		local name = if item then asString(item.name) else nil
		local label = if item then asString(item.label) else nil
		assert(name and store.isValidWorkspace(name) and label and label ~= "", `invalid workspace in {file}`)

		if name == "default" then
			result.workspaces[1].label = label
		elseif not names[name] then
			table.insert(result.workspaces, { name = name, label = label })
			names[name] = true
		end
	end

	for _, entry in json.asArray(raw.archived) or {} do
		local item = json.asObject(entry)
		local name = if item then asString(item.name) else nil
		local label = if item then asString(item.label) else nil
		assert(name and store.isValidWorkspace(name) and label and label ~= "", `invalid archived workspace in {file}`)
		assert(not names[name], `workspace listed twice in {file}: {name}`)
		names[name] = true
		table.insert(result.archived, { name = name, label = label })
	end

	local active = asString(raw.active) or "default"
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

	local value = json.object({ active = list.active, workspaces = entries })

	if #list.archived > 0 then
		local archived: json.Array = {}

		for _, workspace in list.archived do
			table.insert(archived, json.object({ name = workspace.name, label = workspace.label }))
		end

		value.archived = archived
	end

	local file = tostring(path.join(root, fileNames.workspaces))
	workspaceWriteSequence += 1
	local temporary = `{file}.tmp.{process.pid()}.{workspaceWriteSequence}`
	fs.writeStringToFile(temporary, json.serialize(value, true))
	fs.move(temporary, file)
end

function store.getActiveWorkspace(root: string, requested: string?, configured: string?): string
	local list = store.getWorkspaces(root)
	local name = requested or (if configured ~= "" then configured else nil) or list.active
	assert(store.isValidWorkspace(name), `invalid workspace name: {name}`)

	for _, workspace in list.workspaces do
		if workspace.name == name then
			return name
		end
	end

	error(`unknown workspace: {name}`)
end

-- Without a name, the label names the workspace. An explicit name must be a lowercase slug.
function store.createWorkspace(root: string, name: string?, label: string?): WorkspaceList
	assert(label == nil or label:match("%S"), "label must be nonempty")
	assert(name or label, "give a name or a label")
	local workspaceName = name or deriveWorkspaceName(label :: string)
	assert(store.isValidWorkspace(workspaceName), `invalid workspace name: {workspaceName}`)
	local list = store.getWorkspaces(root)

	for _, workspace in list.workspaces do
		assert(workspace.name ~= workspaceName, `workspace already exists: {workspaceName}`)
	end

	local dir = store.getWorkspaceDir(root, workspaceName)
	assert(not fs.exists(dir), `workspace folder already exists: {dir}`)
	store.write(dir, store.createEmptyDoc())
	table.insert(list.workspaces, { name = workspaceName, label = label or workspaceName })
	writeWorkspaces(root, list)
	return list
end

function store.useWorkspace(root: string, name: string): WorkspaceList
	local list = store.getWorkspaces(root)
	assert(store.isValidWorkspace(name), `invalid workspace name: {name}`)
	local isKnown = false

	for _, workspace in list.workspaces do
		isKnown = isKnown or workspace.name == name
	end

	assert(isKnown, `unknown workspace: {name}`)
	list.active = name
	writeWorkspaces(root, list)
	return list
end

function store.renameWorkspace(root: string, name: string, label: string): WorkspaceList
	assert(store.isValidWorkspace(name), `invalid workspace name: {name}`)
	assert(label:match("%S"), "label must be nonempty")
	local list = store.getWorkspaces(root)

	for _, workspace in list.workspaces do
		if workspace.name == name then
			workspace.label = label
			writeWorkspaces(root, list)
			return list
		end
	end

	error(`unknown workspace: {name}`)
end

-- Takes a workspace off the list without touching its folder. The default workspace is the data root
-- itself and is always listed, so it can't be archived, and neither can the one in use.
function store.archiveWorkspace(root: string, name: string, inUse: string): WorkspaceList
	assert(store.isValidWorkspace(name), `invalid workspace name: {name}`)
	assert(name ~= "default", "the default workspace can't be archived")
	local list = store.getWorkspaces(root)
	assert(name ~= list.active and name ~= inUse, `can't archive the active workspace: {name}`)

	for _, workspace in list.archived do
		assert(workspace.name ~= name, `workspace already archived: {name}`)
	end

	for index, workspace in list.workspaces do
		if workspace.name == name then
			table.remove(list.workspaces, index)
			table.insert(list.archived, workspace)
			writeWorkspaces(root, list)
			return list
		end
	end

	error(`unknown workspace: {name}`)
end

-- Puts an archived workspace back on the list. Its folder is still in place, so it returns with its data.
function store.restoreWorkspace(root: string, name: string): WorkspaceList
	assert(store.isValidWorkspace(name), `invalid workspace name: {name}`)
	local list = store.getWorkspaces(root)

	for index, workspace in list.archived do
		if workspace.name == name then
			local dir = store.getWorkspaceDir(root, name)
			assert(fs.exists(dir), `workspace folder is missing: {dir}`)
			table.remove(list.archived, index)
			table.insert(list.workspaces, workspace)
			writeWorkspaces(root, list)
			return list
		end
	end

	error(`unknown archived workspace: {name}`)
end

function store.filePath(dir: string): string
	return tostring(path.join(dir, fileNames.document))
end

function store.getBackupName(revision: number, now: number): string
	return `orion-r{revision}-{os.date("!%Y%m%dT%H%M%SZ", now)}.json`
end

function store.getBackups(dir: string): { Backup }
	local folder = path.join(dir, fileNames.backups)
	local found: { Backup } = {}

	if not fs.exists(folder) then
		return found
	end

	for _, entry in fs.listDirectory(folder) do
		local revision, time = entry.name:match("^orion%-r(%d+)%-(%d%d%d%d%d%d%d%dT%d%d%d%d%d%dZ)%.json$")

		if entry.type == "file" and revision and time then
			local file = tostring(path.join(folder, entry.name))
			table.insert(found, {
				revision = tonumber(revision) :: number,
				time = time,
				size = fs.metadata(file).size,
				file = file,
			})
		end
	end

	table.sort(found, function(a: Backup, b: Backup)
		return if a.time == b.time then a.file > b.file else a.time > b.time
	end)

	return found
end

function store.pruneBackups(dir: string, now: number)
	local hourCutoff = os.date("!%Y%m%dT%H%M%SZ", now - DAY_SECONDS) :: string
	local dayCutoff = os.date("!%Y%m%d", now - (DAILY_DAYS - 1) * DAY_SECONDS) :: string
	local today = os.date("!%Y%m%d", now) :: string
	local current = os.date("!%Y%m%dT%H%M%SZ", now) :: string
	local keptDays: { [string]: boolean } = {}

	for _, backup in store.getBackups(dir) do
		local day = backup.time:sub(1, 8)
		local isInDailyRange = day >= dayCutoff and day <= today and backup.time <= current

		if backup.time >= hourCutoff and backup.time <= current then
			if isInDailyRange then
				keptDays[day] = true
			end

			continue
		end

		if isInDailyRange and not keptDays[day] then
			keptDays[day] = true
			continue
		end

		fs.remove(backup.file)
	end
end

local function asNumber(value: json.Value): number?
	return if type(value) == "number" then value else nil
end

function store.decode(text: string): Doc
	local root = json.asObject(json.deserialize(text) :: json.Value)
	assert(root, "Orion data must be a JSON object")

	local nodes: { Item } = {}

	for _, raw in json.asArray(root.nodes) or {} do
		local object = json.asObject(raw)
		local id = if object then asString(object.id) else nil
		local kind = if object then asString(object.type) else nil

		if object and id and kind then
			local position = json.asObject(object.position) or json.object({})
			table.insert(nodes, {
				id = id,
				type = kind,
				position = { x = asNumber(position.x) or 0, y = asNumber(position.y) or 0 },
				parentId = asString(object.parentId),
				width = asNumber(object.width),
				height = asNumber(object.height),
				data = json.asObject(object.data) or json.object({}),
			})
		end
	end

	local links: { Link } = {}

	for _, raw in json.asArray(root.links) or {} do
		local object = json.asObject(raw)
		local from = if object then asString(object.from) else nil
		local to = if object then asString(object.to) else nil

		if object and from and to then
			table.insert(links, {
				id = asString(object.id) or `{from}>{to}`,
				from = from,
				to = to,
				kind = asString(object.kind) or "blocks",
				origin = asString(object.origin),
			})
		end
	end

	local settings = json.asObject(root.settings) or json.object({})
	local sources: { Source } = {}
	local cover = asString(settings.cover)
	local background = asString(settings.background)

	for _, raw in json.asArray(settings.sources) or {} do
		local source = json.asObject(raw)

		if source and type(source.id) == "string" and type(source.kind) == "string" then
			local function getStrings(value: json.Value): { string }?
				local array = json.asArray(value)

				if not array then
					return nil
				end

				local result = {}

				for _, entry in array do
					if type(entry) == "string" then
						table.insert(result, entry)
					end
				end

				return result
			end

			table.insert(sources, {
				id = source.id,
				kind = source.kind,
				host = asString(source.host),
				owners = getStrings(source.owners),
				include = getStrings(source.include),
				exclude = getStrings(source.exclude),
				command = getStrings(source.command),
				browse = asString(source.browse),
			})
		end
	end

	local version = asNumber(root.version) or 1
	local owner = asString(settings.githubOwner)

	if not owner then
		for _, source in sources do
			if source.kind == "github" then
				owner = if source.owners then source.owners[1] else nil
				break
			end
		end
	end

	owner = owner or "flipbook-labs"

	for _, item in nodes do
		if
			item.type == "task"
			and (
				version < 2
				or item.data.pr ~= nil
				or item.data.external ~= nil
				or item.data.github ~= nil
				or item.data.activity ~= nil
				or item.data.sources ~= nil
				or item.data.issue ~= nil
				or item.data.branch ~= nil
				or item.data.host ~= nil
			)
		then
			migrateItem(item, owner, sources)
		end
	end

	return {
		version = 2,
		revision = asNumber(root.revision) or 0,
		settings = { sources = sources, cover = cover, background = background },
		nodes = nodes,
		links = links,
		github = json.asObject(root.github),
		suggestions = json.asObject(root.suggestions),
		raw = json.object(root),
	}
end

function store.toObject(doc: Doc): json.Object
	local function getStringArray(values: { string }?): json.Array?
		if not values then
			return nil
		end

		local result: json.Array = {}

		for _, value in values do
			table.insert(result, value)
		end

		return result
	end

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
		local object = json.object({ id = link.id, from = link.from, to = link.to, kind = link.kind })
		object.origin = link.origin
		table.insert(links, object)
	end

	local root = json.object(doc.raw or {})
	root.version = 2
	root.revision = doc.revision
	local settings = json.object(json.asObject(root.settings) or {})
	settings.githubOwner = nil
	local sources: json.Array = {}

	for _, source in doc.settings.sources do
		local value = json.object({ id = source.id, kind = source.kind })
		value.host = source.host
		value.owners = getStringArray(source.owners)
		value.include = getStringArray(source.include)
		value.exclude = getStringArray(source.exclude)
		value.command = getStringArray(source.command)
		value.browse = source.browse
		table.insert(sources, value)
	end

	settings.sources = sources
	settings.cover = doc.settings.cover
	settings.background = doc.settings.background
	root.settings = settings
	root.nodes = nodes
	root.links = links
	root.github = doc.github
	root.suggestions = doc.suggestions
	return root
end

function store.encode(doc: Doc): string
	return json.serialize(store.toObject(doc), true)
end

function store.read(dir: string): Doc?
	local file = store.filePath(dir)

	if not fs.exists(file) then
		return nil
	end

	return store.decode(fs.readFileToString(file))
end

function store.decodeFocus(text: string): Focus
	local root = json.asObject(json.deserialize(text) :: json.Value)
	assert(root, "Orion focus must be a JSON object")
	local selected: { string } = {}
	for _, id in json.asArray(root.selected) or {} do
		if type(id) == "string" then
			table.insert(selected, id)
		end
	end
	return { open = asString(root.open), selected = selected, updatedAt = asString(root.updatedAt) }
end

-- Nil when the app isn't open, or caught the file mid-replace.
function store.readFocus(dir: string): Focus?
	local file = path.join(dir, fileNames.focus)
	if not fs.exists(file) then
		return nil
	end
	local succeeded, focus = pcall(function()
		return store.decodeFocus(fs.readFileToString(file))
	end)
	return if succeeded then focus else nil
end

function store.clearFocus(dir: string)
	local file = tostring(path.join(dir, fileNames.focus))
	if fs.exists(file) then
		fs.remove(file)
	end
end

local focusWriteSequence = 0

function store.putFocus(dir: string, tab: string, open: string?, selected: json.Array?, isClosed: boolean?)
	local file = tostring(path.join(dir, fileNames.focus))
	if isClosed then
		if fs.exists(file) then
			local didRead, value = pcall(function()
				return json.asObject(json.deserialize(fs.readFileToString(file)) :: json.Value)
			end)
			if didRead and value and value.tab == tab then
				store.clearFocus(dir)
			end
		end
		return
	end
	if not fs.exists(dir) then
		fs.createDirectory(dir, { makeParents = true })
	end
	focusWriteSequence += 1
	local temporary = `{file}.tmp.{process.pid()}.{focusWriteSequence}`
	local value = json.object({
		tab = tab,
		open = open or json.null,
		selected = selected or {},
		updatedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
	})
	local didWrite, message = pcall(function()
		fs.writeStringToFile(temporary, json.serialize(value, true))
		fs.move(temporary, file)
	end)
	if not didWrite then
		pcall(fs.remove, temporary)
		error(message, 0)
	end
end

function store.createEmptyDoc(): Doc
	return {
		version = 2,
		revision = 0,
		settings = { sources = {} },
		nodes = {},
		links = {},
	}
end

-- A workspace without a data file reads as empty; the first change writes it.
function store.load(dir: string): Doc
	return store.read(dir) or store.createEmptyDoc()
end

local function release(lockPath: string)
	pcall(function()
		fs.removeDirectory(lockPath, { recursive = true })
	end)
end

local function acquire(dir: string): string
	local lockPath = tostring(path.join(dir, fileNames.lock))
	local ownerPath = path.join(lockPath, "owner")
	local deadline = os.time() + LOCK_TIMEOUT_SECONDS

	while true do
		if process.run({ "mkdir", lockPath }).ok then
			fs.writeStringToFile(ownerPath, `{process.pid()} {os.time()}`)
			return lockPath
		end

		-- Reclaim a lock left behind by a writer that crashed.
		local succeeded, owner = pcall(fs.readFileToString, ownerPath)
		local stamp = if succeeded then tonumber(owner:match("%s(%d+)")) else nil

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
	-- Backups are best-effort: a failed backup never blocks the write itself.
	pcall(function()
		if fs.exists(file) then
			local now = os.time()
			local dir = path.dirname(file)
			local folder = path.join(dir, fileNames.backups)
			if not fs.exists(folder) then
				fs.createDirectory(folder)
			end

			local previous = store.decode(fs.readFileToString(file))
			local backup = path.join(folder, store.getBackupName(previous.revision, now))

			if not fs.exists(backup) then
				fs.copy(file, backup)
			end

			store.pruneBackups(dir, now)
		end
	end)

	local succeeded, failureMessage = pcall(fs.move, temporary, file)

	if not succeeded then
		pcall(fs.remove, temporary)
		error(failureMessage, 0)
	end
end

-- Reads the latest data under the lock, applies `mutate`, and writes the next revision.
function store.transaction(dir: string, mutate: (Doc) -> ()): Doc
	if not fs.exists(dir) then
		fs.createDirectory(dir, { makeParents = true })
	end

	local lockPath = acquire(dir)
	local succeeded, result = pcall(function(): Doc
		local doc = store.load(dir)
		local previous = graph.recordedStatuses(doc)
		mutate(doc)
		graph.markCelebrations(doc, previous)
		doc.revision += 1
		atomicWrite(store.filePath(dir), store.encode(doc))
		return doc
	end)

	release(lockPath)

	if not succeeded then
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
	local succeeded, failureMessage = pcall(atomicWrite, store.filePath(dir), store.encode(doc))
	release(lockPath)

	if not succeeded then
		error(failureMessage, 0)
	end
end

return table.freeze(store)
