if true then
	return {}
end

return {
	{
		name = "A",
		setup = function()
			print("A loaded")
		end,
	},

	{
		name = "B",
		event = "VeryLazy",
		setup = function()
			print("B loaded")
		end,
	},

	{
		name = "C",
		cmd = "TestCmd",
		setup = function()
			print("C loaded")
			vim.api.nvim_create_user_command("TestCmd", function()
				print("C exec")
			end, {})
		end,
	},

	{
		name = "D",
		keys = "<leader>d",
		setup = function()
			print("D loaded")
		end,
	},

	{
		name = "E",
		ft = "lua",
		setup = function()
			print("E loaded")
		end,
	},

	{
		name = "F",
		event = "BufRead",
		setup = function()
			print("F loaded")
		end,
	},
}
