---@class PluginSpec
---@field name           string
---@field url            string
---@field main           string
---@field dependencies?  string[]|PluginSpec[]
---@field lazy?          boolean
---@field event?         string|string[]
---@field ft?            string|string[]
---@field cmd?           string|string[]
---@field keys?          table[]
---@field setup          function
---@field opts?          table|fun(opts:table): table

---@class RawPluginSpec
---@field [1]?           string    --  url  shorthand
---@field url?           string
---@field dependencies?  string[]  --  URL
---@field opts?          table

local M = {}

---@param url string
---@return string
local function url_to_name(url)
	url = url:gsub("^https://github.com/", "")
	url = url:gsub("^git@github.com:", "")
	url = url:gsub("%.git$", "")
	return url:match(".+/(.+)")
end

---@param base table
---@param extra table|fun(opts: table): table?
local function merge_opts(base, extra)
	if type(extra) == "function" then
		local result = extra(base or {})
		if result then
			return result
		end
		return base
	end

	if type(extra) == "table" then
		return vim.tbl_deep_extend("force", base or {}, extra)
	end

	return base
end

local function merge_dependencies(a, b)
	local seen = {}
	local out = {}

	local function add(list)
		for _, p in ipairs(list or {}) do
			if not seen[p.name] then
				seen[p.name] = true
				table.insert(out, p)
			end
		end
	end

	add(a)
	add(b)

	return out
end

local function list_union(a, b)
	local seen = {}
	local out = {}

	local function add(list)
		for _, v in ipairs(list or {}) do
			if not seen[v] then
				seen[v] = true
				table.insert(out, v)
			end
		end
	end

	add(a)
	add(b)

	return out
end

---@param a PluginSpec
---@param b PluginSpec
---@return PluginSpec
local function merge_plugin(a, b)
	-- opts
	a.opts = merge_opts(a.opts, b.opts)

	-- list union
	a.dependencies = merge_dependencies(a.dependencies, b.dependencies)
	a.event = list_union(a.event, type(b.event) == "table" and b.event or { b.event })
	a.cmd = list_union(a.cmd, type(b.cmd) == "table" and b.cmd or { b.cmd })
	a.ft = list_union(a.ft, type(b.ft) == "table" and b.ft or { b.ft })
	a.keys = list_union(a.keys, b.keys)

	-- override fields
	if b.setup then
		a.setup = b.setup
	end
	if b.main then
		a.main = b.main
	end
	if b.priority then
		a.priority = b.priority
	end
	if b.lazy ~= nil then
		a.lazy = b.lazy
	end

	return a
end

---@param dep string|PluginSpec
---@return PluginSpec
local function normalize_dep(dep)
	if type(dep) == "string" then
		return {
			url = dep,
			name = url_to_name(dep),
		}
	elseif type(dep) == "table" then
		local url = dep.url or dep[1]
		if not url then
			error("invalid dependency: " .. vim.inspect(dep))
		end
		return {
			url = url,
			name = url_to_name(url),
		}
	end

	error("invalid dependency type: " .. vim.inspect(dep))
end

---@param entry RawPluginSpec
---@return PluginSpec?
local function normalize_plugin(entry)
	if type(entry) ~= "table" then
		return nil
	end

	local plugin = {}
	for k, v in pairs(entry) do
		plugin[k] = v
	end

	if not plugin.url then
		if type(plugin[1]) == "string" then
			plugin.url = plugin[1]
		end
	end

	if not plugin.url then
		error("plugin.name is required: " .. vim.inspect(entry))
	end

	plugin.name = url_to_name(plugin.url)

	if plugin.dependencies then
		local deps = {}

		for _, dep in ipairs(plugin.dependencies) do
			table.insert(deps, normalize_dep(dep))
		end

		plugin.dependencies = deps
	end

	return plugin
end

---@param entries PluginSpec[]
---@param out PluginSpec
local function flatten(entries, out)
	for _, entry in ipairs(entries) do
		if type(entry) == "table" then
			-- If the entry is a table, and its first element is also a table,
			-- it implies it's a nested list of plugins that needs further flattening.
			if type(entry[1]) == "table" then
				flatten(entry, out)
			else
				-- Otherwise, this entry itself is a plugin definition (a table containing string/other keys)
				table.insert(out, entry)
			end
		end
		-- If entry is not a table, it's ignored. This is correct as normalize_plugin expects a table.
	end
end

---@param entries RawPluginSpec|RawPluginSpec[]
---@return PluginSpec[]
local function normalize_all(entries)
	local flat_plugins = {}

	if
		type(entries) == "table"
		and (entries.url or type(entries[1]) == "string")
		and not (type(entries[1]) == "table")
	then
		local plugin = normalize_plugin(entries)
		if plugin then
			table.insert(flat_plugins, plugin)
		end
		return flat_plugins
	end

	flatten(entries, flat_plugins)

	local out = {}
	for _, entry in ipairs(flat_plugins) do
		local plugin = normalize_plugin(entry)
		if plugin then
			table.insert(out, plugin)
		end
	end
	return out
end

---@param module string
---@return PluginSpec[]
local function load_spec_file(module)
	local ok, spec = pcall(require, module)

	if not ok or not spec then
		return {}
	end

	return normalize_all(spec)
end

---@return PluginSpec[]
function M.get()
	local map = {}

	local plugin_dir = vim.fn.stdpath("config") .. "/lua/plugins"
	local uv = vim.loop
	local handle = uv.fs_scandir(plugin_dir)

	if not handle then
		return {}
	end

	while true do
		local name, type = uv.fs_scandir_next(handle)
		if not name then
			break
		end

		if type == "file" and name:match("%.lua$") then
			local module = "plugins." .. name:gsub("%.lua$", "")
			local specs_from_file = load_spec_file(module) -- Returns a list of normalized plugins

			for _, p in ipairs(specs_from_file) do
				if not map[p.name] then
					map[p.name] = p
				else
					map[p.name] = merge_plugin(map[p.name], p)
				end
			end
		end
	end

	local results = {}
	for _, p in pairs(map) do
		table.insert(results, p)
	end

	return results
end

return M
