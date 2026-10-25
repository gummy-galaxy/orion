--[[
	Writes `workspace/orion-app/dist/acknowledgements.html`, the page the desktop app opens from Help › Acknowledgements. It lists
	the license of every third-party project the app ships: the npm packages Vite bundles into the canvas, the Rust
	crates compiled into the shell, the Luau packages compiled into the CLI sidecar, and the native libraries in
	Lute's runtime. Run it after the canvas build, which writes Vite's license report.
]]
local fs = require("@std/fs")
local json = require("@std/json")
local loomConfig = require("@repo/loom.config")
local net = require("@std/net")
local path = require("@std/path")
local process = require("@std/process")

local runScript = require("@root/runScript")

type Project = {
	name: string,
	version: string,
	license: string?,
	text: string?,
	url: string?,
}

type Dependency = {
	rev: string,
	source: string,
}

type Section = {
	title: string,
	projects: { Project },
}

local workspaceDir = path.resolve("..")
local dist = path.join(workspaceDir, "orion-app", "dist")
local shell = path.join(workspaceDir, "orion-desktop")
local store = path.join(process.homedir(), ".loom", "store")

local LICENSE_FILE_PREFIXES = { "license", "licence", "copying", "unlicense" }
local REMOTE_LICENSE_FILES = { "LICENSE", "LICENSE.txt", "LICENSE.md", "COPYING" }
-- Lute pins these for its own tests; they aren't part of the runtime.
local TEST_ONLY_LIBRARIES = { ["toml-test"] = true }

local function optionalString(value: unknown): string?
	return if type(value) == "string" and value ~= "" then value else nil
end

-- Runs a command quietly and returns what it printed; cargo metadata alone prints megabytes of JSON.
local function output(command: { string }): string
	local result = process.run(command)
	assert(result.ok, `{command[1]} failed: {result.stderr}`)
	return result.stdout
end

local function isLicenseFile(name: string): boolean
	local lowered = string.lower(name)
	for _, prefix in LICENSE_FILE_PREFIXES do
		if string.sub(lowered, 1, #prefix) == prefix then
			return true
		end
	end

	return false
end

-- Joins every license file in a package's folder, such as both halves of an MIT OR Apache-2.0 crate.
local function readLicenseFiles(directory: path.Pathlike): string?
	local names: { string } = {}
	for _, entry in fs.listDirectory(directory) do
		if entry.type == "file" and isLicenseFile(entry.name) then
			table.insert(names, entry.name)
		end
	end
	table.sort(names)

	local texts: { string } = {}
	for _, name in names do
		table.insert(texts, fs.readFileToString(path.join(directory, name)))
	end

	return if #texts > 0 then table.concat(texts, "\n\n") else nil
end

local function javascriptPackages(): { Project }
	local reportPath = path.join(dist, ".vite", "licenses.json")
	assert(fs.exists(reportPath), `{reportPath} is missing; build the canvas first`)

	local report = json.deserialize(fs.readFileToString(reportPath)) :: { any }
	local projects = {}
	for _, entry in report do
		table.insert(projects, {
			name = entry.name,
			version = entry.version,
			license = optionalString(entry.identifier),
			text = optionalString(entry.text),
			url = `https://www.npmjs.com/package/{entry.name}`,
		})
	end

	return projects
end

local function isProcMacro(package: any): boolean
	for _, target in package.targets do
		if table.find(target.kind, "proc-macro") then
			return true
		end
	end

	return false
end

-- Follows the shell's normal dependencies for this platform. Build scripts and procedural macros only run while
-- compiling, so neither they nor what only they depend on end up in the app.
local function rustCrates(): { Project }
	local rustcVersion = output({ "rustc", "-vV" })
	local triple = assert(string.match(rustcVersion, "host: (%S+)"), "Could not determine the Rust host target triple")
	local metadata = json.deserialize(output({
		"cargo",
		"metadata",
		"--format-version",
		"1",
		"--manifest-path",
		tostring(path.join(shell, "Cargo.toml")),
		"--filter-platform",
		triple,
	})) :: any

	local packagesById = {}
	for _, package in metadata.packages do
		packagesById[package.id] = package
	end

	local nodesById = {}
	for _, node in metadata.resolve.nodes do
		nodesById[node.id] = node
	end

	local rootId = metadata.resolve.root
	local visited = { [rootId] = true }
	local queue = { rootId }
	local projects = {}
	while #queue > 0 do
		local id = table.remove(queue, 1)
		for _, dependency in nodesById[id].deps do
			local isNormal = false
			for _, kind in dependency.dep_kinds do
				if kind.kind == json.null then
					isNormal = true
				end
			end

			local package = packagesById[dependency.pkg]
			if isNormal and not visited[dependency.pkg] and not isProcMacro(package) then
				visited[dependency.pkg] = true
				table.insert(queue, dependency.pkg)
				table.insert(projects, {
					name = package.name,
					version = package.version,
					license = optionalString(package.license),
					text = readLicenseFiles(path.dirname(package.manifest_path)),
					url = `https://crates.io/crates/{package.name}`,
				})
			end
		end
	end

	return projects
end

local function luauPackages(): { Project }
	local projects = {}
	local dependencies = loomConfig.package.dependencies :: { [string]: Dependency }
	for name, dependency in dependencies do
		local directory = path.join(store, `{name}@{dependency.rev}`)
		assert(fs.exists(directory), `{directory} is missing; run lute pkg install`)

		table.insert(projects, {
			name = name,
			version = dependency.rev,
			license = nil,
			text = readLicenseFiles(directory),
			url = dependency.source,
		})
	end

	return projects
end

local function fetchLicense(remote: string, revision: string): string?
	local repository = string.match(remote, "^https://github%.com/(.-)%.git$")
		or string.match(remote, "^https://github%.com/(.-)/?$")
	if not repository then
		return nil
	end

	for _, name in REMOTE_LICENSE_FILES do
		local url = `https://raw.githubusercontent.com/{repository}/{revision}/{name}`
		local fetched, response = pcall(function()
			return net.request(url)
		end)
		if fetched and response.ok then
			return response.body
		end
	end

	return nil
end

-- Lute pins each library it links into its runtime with a `.tune` file. Their license texts aren't in the package,
-- so they're fetched from each repository at the pinned revision. Without a network connection the page still
-- lists the library and links to it.
local function luteLibraries(): { Project }
	local lute = loomConfig.package.dependencies.lute
	local extern = path.join(store, `lute@{lute.rev}`, "extern")

	local projects = {}
	for _, entry in fs.listDirectory(extern) do
		local tune = string.match(entry.name, "^(.+)%.tune$")
		if tune and not TEST_ONLY_LIBRARIES[tune] then
			local contents = fs.readFileToString(path.join(extern, entry.name))
			local name = assert(string.match(contents, 'name = "([^"]+)"'), `{entry.name} has no name`)
			local remote = assert(string.match(contents, 'remote = "([^"]+)"'), `{entry.name} has no remote`)
			local revision = assert(string.match(contents, 'revision = "([^"]+)"'), `{entry.name} has no revision`)
			local branch = string.match(contents, 'branch = "([^"]+)"')

			local text = fetchLicense(remote, revision)
			if not text then
				print(`Could not fetch the license for {name}; the page links to {remote} instead`)
			end

			table.insert(projects, {
				name = name,
				version = branch or string.sub(revision, 1, 7),
				license = nil,
				text = text,
				url = string.gsub(remote, "%.git$", ""),
			})
		end
	end

	return projects
end

local function escape(text: string): string
	return (
		string.gsub(text, '[&<>"]', {
			["&"] = "&amp;",
			["<"] = "&lt;",
			[">"] = "&gt;",
			['"'] = "&quot;",
		})
	)
end

local SPDX_OPERATORS = { AND = true, OR = true, WITH = true }

-- Some packages ship without their license files, so each SPDX identifier in their license expression links to
-- the canonical text instead.
local function linkIdentifiers(expression: string): string
	return (
		string.gsub(escape(expression), "[%w%.%-%+]+", function(token: string): string
			if SPDX_OPERATORS[token] then
				return token
			end

			return `<a href="https://spdx.org/licenses/{token}.html">{token}</a>`
		end)
	)
end

local STYLE = [[
:root {
  --bg: #f3f5f6;
  --surface: #ffffff;
  --ink: #17242b;
  --muted: #5d6d75;
  --line: #d3dbdf;
  --accent: #0d6f74;
  color-scheme: light dark;
}
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #0f1619;
    --surface: #172227;
    --ink: #e3eaed;
    --muted: #92a3aa;
    --line: #2b3a41;
    --accent: #4fc1c4;
  }
}
* { box-sizing: border-box; }
body {
  margin: 0;
  background: var(--bg);
  color: var(--ink);
  font: 13px/1.5 system-ui, -apple-system, 'Segoe UI', sans-serif;
}
main { max-width: 720px; margin: 0 auto; padding: 32px 24px 48px; }
h1 { font-size: 22px; margin: 0 0 4px; }
h2 { font-size: 13px; text-transform: uppercase; letter-spacing: 0.06em; color: var(--muted); margin: 32px 0 8px; }
p { color: var(--muted); margin: 0; }
a { color: var(--accent); text-decoration: none; }
a:hover { text-decoration: underline; }
ul { list-style: none; margin: 0; padding: 0; background: var(--surface); border: 1px solid var(--line); border-radius: 8px; }
li { display: flex; gap: 12px; align-items: baseline; padding: 6px 12px; border-top: 1px solid var(--line); }
li:first-child { border-top: 0; }
.name { font-weight: 600; }
.version { color: var(--muted); flex: 1; }
article { margin-top: 16px; }
.users { color: var(--muted); margin-bottom: 6px; }
pre {
  margin: 0;
  padding: 12px;
  background: var(--surface);
  border: 1px solid var(--line);
  border-radius: 8px;
  font: 11px/1.45 ui-monospace, 'SF Mono', Menlo, monospace;
  white-space: pre-wrap;
  overflow-wrap: anywhere;
}
]]

local function render(sections: { Section }): string
	local textIndexes: { [string]: number } = {}
	local texts: { string } = {}
	local users: { { string } } = {}
	for _, section in sections do
		for _, project in section.projects do
			local text = project.text
			if text then
				local index = textIndexes[text]
				if not index then
					table.insert(texts, text)
					local projectNames: { string } = {}
					table.insert(users, projectNames)
					index = #texts
					textIndexes[text] = index
				end
				table.insert(users[index], `{project.name} {project.version}`)
			end
		end
	end

	local lines = {
		"<!doctype html>",
		'<html lang="en">',
		"<head>",
		'<meta charset="utf-8">',
		'<meta name="viewport" content="width=device-width, initial-scale=1">',
		"<title>Acknowledgements</title>",
		`<style>{STYLE}</style>`,
		"</head>",
		"<body>",
		"<main>",
		"<h1>Acknowledgements</h1>",
		"<p>Orion is built on these open-source projects. Thank you to everyone who works on them.</p>",
	}

	for _, section in sections do
		table.insert(lines, `<h2>{escape(section.title)}</h2>`)
		table.insert(lines, "<ul>")
		for _, project in section.projects do
			local name = escape(project.name)
			if project.url then
				name = `<a class="name" href="{escape(project.url)}">{name}</a>`
			else
				name = `<span class="name">{name}</span>`
			end

			local label = escape(project.license or "License")
			local license = if project.text
				then `<a href="#license-{textIndexes[project.text]}">{label}</a>`
				elseif project.license then linkIdentifiers(project.license)
				else ""

			table.insert(lines, `<li>{name}<span class="version">{escape(project.version)}</span>{license}</li>`)
		end
		table.insert(lines, "</ul>")
	end

	table.insert(lines, "<h2>License texts</h2>")
	for index, text in texts do
		table.insert(lines, `<article id="license-{index}">`)
		table.insert(lines, `<p class="users">{escape(table.concat(users[index], ", "))}</p>`)
		table.insert(lines, `<pre>{escape(text)}</pre>`)
		table.insert(lines, "</article>")
	end

	table.insert(lines, "</main>")
	table.insert(lines, "</body>")
	table.insert(lines, "</html>")
	return table.concat(lines, "\n") .. "\n"
end

local function byName(a: Project, b: Project): boolean
	local left, right = string.lower(a.name), string.lower(b.name)
	if left ~= right then
		return left < right
	end

	return a.version < b.version
end

runScript(function()
	local sections: { Section } = {
		{ title = "Canvas", projects = javascriptPackages() },
		{ title = "Desktop shell", projects = rustCrates() },
		{ title = "Command-line tool", projects = luauPackages() },
		{ title = "Lute runtime", projects = luteLibraries() },
	}

	local count = 0
	for _, section in sections do
		table.sort(section.projects, byName)
		count += #section.projects
	end

	local outputPath = path.join(dist, "acknowledgements.html")
	fs.writeStringToFile(outputPath, render(sections))
	print(`Wrote {count} projects to {outputPath}`)
end)
