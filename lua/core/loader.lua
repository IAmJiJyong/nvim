local specs = require("core.specs")
local state = require("core.state")
local trigger = require("core.trigger")
local event = require("core.event")

local M = {}

-- ╭─────────────────────────────────────────────────────────╮
-- │ load plugin                                             │
-- ╰─────────────────────────────────────────────────────────╯
local function _load_plugin_actual(plugin)
	if state.is_loaded(plugin.name) then
		return true
	end

	if plugin.url then
		vim.pack.add({
			{ src = plugin.url },
		})
	end

	local ok, err = pcall(function()
		if plugin.setup then
			plugin.setup()
		end
	end)

	if not ok then
		vim.notify("[loader] failed to setup: " .. plugin.name .. "\n" .. err, vim.log.levels.ERROR)
		return false
	end

	print("Loaded plugin: " .. plugin.name)
	return true
end

-- New load function to handle dependencies
local function load(plugin_name, all_plugins, loading_stack)
	if state.is_loaded(plugin_name) then
		return true
	end

	-- Detect circular dependencies
	if loading_stack[plugin_name] then
		vim.notify(
			"[loader] Circular dependency detected! Plugin '"
				.. plugin_name
				.. "' is already in the loading stack. Current stack: "
				.. vim.inspect(vim.tbl_keys(loading_stack)),
			vim.log.levels.ERROR
		)
		return false
	end

	local plugin = all_plugins[plugin_name]
	if not plugin then
		vim.notify(
			"[loader] Dependency not found: '" .. plugin_name .. "'. It is required by another plugin.",
			vim.log.levels.ERROR
		)
		return false
	end

	-- Add to current loading stack
	loading_stack[plugin_name] = true

	-- Process dependencies first
	if plugin.dependencies and type(plugin.dependencies) == "table" then
		for _, dep_name in ipairs(plugin.dependencies) do
			if not load(dep_name, all_plugins, loading_stack) then
				-- If any dependency fails to load, this plugin also fails
				loading_stack[plugin_name] = nil -- Remove from stack before returning
				return false
			end
		end
	end

	-- After all dependencies are loaded, load the current plugin
	local success = _load_plugin_actual(plugin)
	if success then
		state.mark_loaded(plugin_name)
	end

	-- Remove from current loading stack
	loading_stack[plugin_name] = nil

	return success
end

local function register(plugin, all_plugins, loading_stack)
	-- The trigger functions will now call the new 'load' function with dependency handling
	local function trigger_load_wrapper()
		load(plugin.name, all_plugins, loading_stack)
	end
	trigger.event(plugin, trigger_load_wrapper)
	trigger.cmd(plugin, trigger_load_wrapper)
	trigger.keys(plugin, trigger_load_wrapper)
	trigger.ft(plugin, trigger_load_wrapper)
end

-- ╭─────────────────────────────────────────────────────────╮
-- │ Init pipeline                                           │
-- ╰─────────────────────────────────────────────────────────╯
function M.setup()
	local plugins = specs.get()
	local plugin_map = {}
	local loading_stack = {} -- Track plugins currently being processed for circular deps

	for _, p in ipairs(plugins) do
		plugin_map[p.name] = p
	end

	for _, p in ipairs(plugins) do
		if p.event or p.cmd or p.keys then
			register(p, plugin_map, loading_stack)
		end
	end

	for _, p in ipairs(plugins) do
		if not (p.event or p.cmd or p.keys) then
			load(p.name, plugin_map, loading_stack)
		end
	end

	vim.api.nvim_create_autocmd("VimEnter", {
		once = true,
		callback = function()
			vim.schedule(function()
				event.emit("VeryLazy")
			end)
		end,
	})

	print(vim.inspect(state.loaded))
end

return M
