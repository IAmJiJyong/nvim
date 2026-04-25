return {
	{
		"https://github.com/nvim-neo-tree/neo-tree.nvim",
		dependencies = {
			"https://github.com/nvim-lua/plenary.nvim",
			"https://github.com/MunifTanjim/nui.nvim",
			"https://github.com/nvim-tree/nvim-web-devicons",
		},
		keys = {
			{ "<leader>e", ":<Cmd>Neotree toggle<cr>", opts = { desc = "Toggle Neo-tree", silent = true } },
		},
	},
}
