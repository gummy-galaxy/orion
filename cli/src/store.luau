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
local BACKUPS = "backups"
local DAY_SECONDS = 24 * 60 * 60
local DAILY_DAYS = 30
local LOCK_TIMEOUT_SECONDS = 5
local STALE_LOCK_SECONDS = 30
local DEFAULT_OWNER = "flipbook-labs"

local store = {}

function store.defaultDir(): string
	local configured = process.env.ORION_DATA_DIR
	if configured and configured ~= "" then
		return tostring(path.resolve(configured))
	end
	return tostring(path.join(process.homedir(), "Library", "Application Support", "Orion"))
end

function store.filePath(dir: string): string
	return tostring(path.join(dir, FILE))
end

export type Backup = { revision: number, time: string, size: number, file: string }

function store.backupName(revision: number, now: number): string
	return `orion-r{revision}-{os.date("!%Y%m%dT%H%M%SZ", now)}.json`
end

function store.backups(dir: string): { Backup }
	local folder = path.join(dir, BACKUPS)
	local found: { Backup } = {}
	if not fs.exists(folder) then
		return found
	end
	for _, entry in fs.listDirectory(folder) do
		local revision, time = entry.name:match("^orion%-r(%d+)%-(%d%d%d%d%d%d%d%dT%d%d%d%d%d%dZ)%.json$")
		if entry.type == "file" and revision and time then
			local file = tostring(path.join(folder, entry.name))
			table.insert(
				found,
				{ revision = tonumber(revision) :: number, time = time, size = fs.metadata(file).size, file = file }
			)
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
	for _, backup in store.backups(dir) do
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

local function str(value: json.Value): string?
	return if type(value) == "string" then value else nil
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
				origin = str(object.origin),
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
		local object = json.object({ id = link.id, from = link.from, to = link.to, kind = link.kind })
		object.origin = link.origin
		table.insert(links, object)
	end
	local root = json.object(doc.raw or {})
	root.version = doc.version
	root.revision = doc.revision
	local settings = json.object(json.asObject(root.settings) or {})
	settings.githubOwner = doc.settings.githubOwner
	root.settings = settings
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
	-- Backups are best-effort: a failed backup never blocks the write itself.
	pcall(function()
		if fs.exists(file) then
			local now = os.time()
			local dir = path.dirname(file)
			local folder = path.join(dir, BACKUPS)
			if not fs.exists(folder) then
				fs.createDirectory(folder)
			end
			local previous = store.decode(fs.readFileToString(file))
			local backup = path.join(folder, store.backupName(previous.revision, now))
			if not fs.exists(backup) then
				fs.copy(file, backup)
			end
			store.pruneBackups(dir, now)
		end
	end)
	local ok, err = pcall(fs.move, temporary, file)
	if not ok then
		pcall(fs.remove, temporary)
		error(err, 0)
	end
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
