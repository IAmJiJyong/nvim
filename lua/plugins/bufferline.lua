return {
	"https://github.com/akinsho/bufferline.nvim",
	setup = function()
		require("bufferline").setup({
			options = {
				always_show_bufferline = false,
				offsets = {
					{
						filetype = "neo-tree",
						text = "Neo-tree",
						highlight = "Directory",
						text_align = "left",
					},
				},
			},
		})
	end,
}
