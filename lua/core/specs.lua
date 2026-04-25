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
			table.insert(deps, { url = dep, name = url_to_name(dep) })
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
	local all_plugin_entries = {} -- Will store all unique {url, name} entries
	local seen_names = {}
	local seen_urls = {}

	local plugin_dir = vim.fn.stdpath("config") .. "/lua/plugins"

	local uv = vim.loop
	local handle = uv.fs_scandir(plugin_dir)

	if not handle then
		return all_plugin_entries
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
				if not seen_urls[p.url] then
					seen_urls[p.url] = true
					seen_names[p.name] = true
					table.insert(all_plugin_entries, p)

					-- Also process dependencies of this top-level plugin
					if p.dependencies then
						for _, dep_entry in ipairs(p.dependencies) do
							if not seen_urls[dep_entry.url] then
								seen_urls[dep_entry.url] = true
								if not seen_names[dep_entry.name] then
									seen_names[dep_entry.name] = true
									-- Add the dependency as a separate plugin entry
									table.insert(all_plugin_entries, { url = dep_entry.url, name = dep_entry.name })
								end
							end
						end
					end
				end
			end
		end
	end

	-- After collecting all entries, we might need to re-normalize them or ensure they are properly structured.
	-- For now, this will return a flat list of all unique plugins (main + dependencies).
	return all_plugin_entries
end

return M
