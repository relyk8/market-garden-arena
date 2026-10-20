--[[
	Quality gate: format, lint, and type-check Luau sources.

	Usage:
		lune run check                 -- check everything under src/
		lune run check --fix           -- format with StyLua instead of only checking
		lune run check src/a.luau ...  -- limit to specific files
]]

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")

local LUAU_LSP_VERSION = "1.70.1" -- keep in sync with rokit.toml
local DEFS_DIR = ".luau-lsp"
local DEFS_PATH = `{DEFS_DIR}/globalTypes-{LUAU_LSP_VERSION}.d.luau`
local DEFS_URL =
	`https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/{LUAU_LSP_VERSION}/scripts/globalTypes.d.luau`

local fix = false
local targets = {}
for _, arg in process.args do
	if arg == "--fix" then
		fix = true
	else
		table.insert(targets, arg)
	end
end
if #targets == 0 then
	targets = { "src" }
end

local function run(label: string, program: string, args: { string }): boolean
	local result = process.exec(program, args)
	local lines = {}
	for line in (result.stdout .. result.stderr):gmatch("[^\r\n]+") do
		-- luau-lsp logs its startup steps; only the diagnostics matter
		if not line:match("^%[INFO%]") and not line:match("^%[WARN%]") then
			table.insert(lines, line)
		end
	end
	local output = table.concat(lines, "\n")
	if result.ok then
		print(`[ok]   {label}`)
	else
		print(`[FAIL] {label}`)
		print(output)
	end
	return result.ok
end

local function ensureDefinitions()
	if fs.isFile(DEFS_PATH) then
		return
	end
	print(`fetching Roblox type definitions for luau-lsp {LUAU_LSP_VERSION}...`)
	local response = net.request(DEFS_URL)
	assert(response.ok, `failed to download type definitions: HTTP {response.statusCode}`)
	if not fs.isDir(DEFS_DIR) then
		fs.writeDir(DEFS_DIR)
	end
	fs.writeFile(DEFS_PATH, response.body)
end

ensureDefinitions()

local passed = true
local function step(label: string, program: string, args: { string })
	passed = run(label, program, args) and passed
end

step("sourcemap", "rojo", { "sourcemap", "default.project.json", "--output", "sourcemap.json" })

local styluaArgs = table.clone(targets)
if not fix then
	table.insert(styluaArgs, 1, "--check")
end
step(if fix then "stylua (format)" else "stylua", "stylua", styluaArgs)

step("selene", "selene", targets)

local analyzeArgs = {
	"analyze",
	"--sourcemap=sourcemap.json",
	`--definitions={DEFS_PATH}`,
	"--base-luaurc=.luaurc",
	"--no-strict-dm-types",
}
for _, target in targets do
	table.insert(analyzeArgs, target)
end
step("luau-lsp analyze", "luau-lsp", analyzeArgs)

process.exit(if passed then 0 else 1)
