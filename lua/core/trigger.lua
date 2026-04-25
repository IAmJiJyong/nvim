local event = require("core.event")
local state = require("core.state")

local M = {}

function M.event(plugin, load)
	if not plugin.event then
		return
	end

	local events = type(plugin.event) == "table" and plugin.event or { plugin.event }

	for _, ev in ipairs(events) do
		local kind, name = event.normalize_event(ev)

		if kind == "nvim" then
			vim.api.nvim_create_autocmd(name, {
				once = true,
				callback = function()
					load(plugin)
				end,
			})
		elseif kind == "User" then
			vim.api.nvim_create_autocmd("User", {
				pattern = name,
				once = true,
				callback = function()
					load(plugin)
				end,
			})
		end
	end
end

function M.cmd(plugin, load)
	if not plugin.cmd then
		return
	end

	local cmds = type(plugin.cmd) == "table" and plugin.cmd or { plugin.cmd }

	for _, cmd in ipairs(cmds) do
		vim.api.nvim_create_user_command(cmd, function()
			vim.api.nvim_del_user_command(cmd)
			print("before load")
			load(plugin)
			print("after load")
			print(vim.inspect(vim.api.nvim_get_commands({})["TestCmd"]))
			vim.cmd(cmd)
		end, {})
	end
end

function M.ft(plugin, load)
	if not plugin.ft then
		return
	end

	local fts = type(plugin.ft) == "table" and plugin.ft or { plugin.ft }

	vim.api.nvim_create_autocmd("FileType", {
		pattern = fts,
		once = true,
		callback = function()
			load(plugin)
		end,
	})
end

function M.keys(plugin, load)
	if not plugin.keys then
		return
	end

	for _, key in ipairs(plugin.keys) do
		local lhs = key[1]
		local rhs = key[2]

		local modes = key.mode or "n"
		if type(modes) == "string" then
			modes = { modes }
		end

		if rhs == false then
			for _, m in ipairs(modes) do
				pcall(vim.keymap.del, m, lhs)
			end
		else
			for _, m in ipairs(modes) do
				local replaced = false

				vim.keymap.set(m, lhs, function()
					-- ⭐ load once
					if not state.loaded[plugin.name] then
						load(plugin)
					end

					if not replaced then
						replaced = true

						local opts = {
							desc = key.desc,
							silent = key.silent ~= false,
							expr = key.expr,
							nowait = key.nowait,
							buffer = key.buffer,
							remap = key.remap,
						}

						-- ⭐ replace keymap
						vim.keymap.set(m, lhs, rhs, opts)
					end

					-- ⭐ execute
					if type(rhs) == "string" then
						vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(rhs, true, false, true), "m", false)
					else
						rhs()
					end
				end, {
					desc = key.desc,
					silent = true,
				})
			end
		end
	end
end

return M
