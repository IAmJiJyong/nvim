local M = {
	loaded = {},
}

function M.is_loaded(name)
	return M.loaded[name] == true
end

function M.mark_loaded(name)
	M.loaded[name] = true
end

return M
