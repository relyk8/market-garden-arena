--[[
	Claude Code PostToolUse hook: after Claude edits a .luau file under src/,
	format it and run the quality gate on it. failures exit with code 2 so the
	diagnostics are fed back to Claude.
]]

local process = require("@lune/process")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")

local ok, payload = pcall(serde.decode, "json" :: "json", stdio.readToEnd())
local filePath = ok and payload.tool_input and payload.tool_input.file_path
if type(filePath) ~= "string" then
	process.exit(0)
end

local path = filePath:gsub("\\", "/")
local relative = path:match("/(src/.+%.luau)$") or path:match("^(src/.+%.luau)$")
if not relative then
	process.exit(0)
end

local result = process.exec("lune", { "run", "check", "--fix", relative })
if not result.ok then
	stdio.ewrite(`Quality gate failed for {relative}:\n{result.stdout}{result.stderr}`)
	process.exit(2)
end
