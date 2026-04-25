local M = {}

function M.emit(event)
	vim.cmd("doautocmd User " .. event)
end

function M.on(event, cb, opts)
	opts = opts or {}
	vim.api.nvim_create_autocmd("User", {
		pattern = event,
		once = opts.once,
		callback = cb,
	})
end

function M.normalize_event(ev)
	if ev:match("^User ") then
		return "User", ev:gsub("^User ", "")
	end

	local aliases = {
		VeryLazy = "User VeryLazy",
	}

	if aliases[ev] then
		return "User", aliases[ev]:gsub("^User ", "")
	end

	return "nvim", ev
end

return M
