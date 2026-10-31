local path = require("@std/path")

local joinRepositoryPath = require("@root/storybook/joinRepositoryPath")
local types = require("@root/storybook/types")

type ReadFile = types.ReadFile
type Story = types.Story

-- What TypeScript tries after a relative specifier, in order.
local SUFFIXES = { "", ".ts", ".tsx", "/index.ts", "/index.tsx" }

-- `import … from './x'` and `export … from './x'`, `import './x.css'`, and
-- `import('./x')`.
local IMPORT_PATTERNS = {
	"from%s*['\"](%.[^'\"]+)['\"]",
	"import%s*['\"](%.[^'\"]+)['\"]",
	"import%s*%(%s*['\"](%.[^'\"]+)['\"]",
}

--[[
	Finds the stories that load a changed file. It follows each stories file's
	relative imports, and the imports of the files they import, and returns how
	many imports away the nearest changed file is, keyed by stories file: 0 when
	the stories file itself changed, 1 when it imports a changed file, and so
	on. Stories files that never reach a changed file are left out. Paths are
	from the repository root, and `readFile` reads them.
]]
local function findTouchedStories(
	stories: { Story },
	changedFiles: { string },
	readFile: ReadFile
): { [string]: number }
	local changed = {}
	local sources: { [string]: string | false } = {}
	local imports: { [string]: { string } } = {}
	local touched = {}

	for _, file in changedFiles do
		changed[file] = true
	end

	local function read(file: string): string?
		if sources[file] == nil then
			sources[file] = readFile(file) or false
		end

		return sources[file] or nil
	end

	local function getImports(file: string): { string }
		if imports[file] then
			return imports[file]
		end

		local found = {}
		local source = read(file) or ""
		local directory = path.dirname(file)

		for _, pattern in IMPORT_PATTERNS do
			for specifier in string.gmatch(source, pattern) do
				local base = joinRepositoryPath(directory, specifier)

				for _, suffix in SUFFIXES do
					if read(base .. suffix) then
						table.insert(found, base .. suffix)
						break
					end
				end
			end
		end

		imports[file] = found

		return found
	end

	for _, story in stories do
		if touched[story.file] ~= nil then
			continue
		end

		-- Breadth first, so the first changed file found is the nearest one.
		local depths = { [story.file] = 0 }
		local queue = { story.file }
		local cursor = 1

		while queue[cursor] do
			local file = queue[cursor]
			cursor += 1

			if changed[file] then
				touched[story.file] = depths[file]
				break
			end

			for _, imported in getImports(file) do
				if depths[imported] == nil then
					depths[imported] = depths[file] + 1
					table.insert(queue, imported)
				end
			end
		end
	end

	return touched
end

return findTouchedStories
