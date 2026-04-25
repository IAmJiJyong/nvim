local M = {}

local function url_to_name(url)
	url = url:gsub("^https://github.com/", "")
	url = url:gsub("^git@github.com:", "")
	url = url:gsub("%.git$", "")
	return url:match(".+/(.+)")
end

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
			table.insert(deps, url_to_name(dep))
		end

		plugin.dependencies = deps
	end

	return plugin
end

local function flatten(entries, out)
	for _, entry in ipairs(entries) do
		if type(entry) == "table" and type(entry[1]) == "table" then
			flatten(entry, out)
		else
			table.insert(out, entry)
		end
	end
end

local function normalize_all(entries)
	local flat = {}
	local out = {}

	flatten(entries, flat)

	for _, entry in ipairs(flat) do
		local plugin = normalize_plugin(entry)
		if plugin then
			table.insert(out, plugin)
		end
	end

	return out
end

local function load_spec_file(module)
	local ok, spec = pcall(require, module)
	if not ok or not spec then
		return {}
	end

	return normalize_all(spec)
end

function M.get()
	local results = {}
	local seen = {}

	local plugin_dir = vim.fn.stdpath("config") .. "/lua/plugins"

	local uv = vim.loop
	local handle = uv.fs_scandir(plugin_dir)

	if not handle then
		return results
	end

	while true do
		local name, type = uv.fs_scandir_next(handle)
		if not name then
			break
		end

		if type == "file" and name:match("%.lua$") then
			local module = "plugins." .. name:gsub("%.lua$", "")
			local specs = load_spec_file(module)

			for _, p in ipairs(specs) do
				if not seen[p.name] then
					seen[p.name] = true
					table.insert(results, p)
				end
			end
		end
	end

	return results
end

return M
