return {
	"ecthelionvi/NeoComposer.nvim",
	dependencies = { "kkharji/sqlite.lua", "nvim-telescope/telescope.nvim", "nvim-lualine/lualine.nvim" },
	opts = {},
	config = function()
		require("NeoComposer").setup()
		require("telescope").load_extension("macros")
	end,
	keys = {
		{ "<leader>me", "<cmd>EditMacros<cr>", desc = "Edit Macros" },
		{ "<leader>mad", "<cmd>ToggleDelay<cr>", desc = "Macro delays" },
	},
}
