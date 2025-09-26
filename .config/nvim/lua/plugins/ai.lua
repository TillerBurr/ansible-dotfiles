return {
	-- Copilot
	{
		"zbirenbaum/copilot.lua",
		cmd = "Copilot",
		event = "VeryLazy",
		cond = not vim.g.vscode,
		config = function()
			require("copilot").setup({
				suggestion = { enabled = false },
				panel = { enabled = false },
			})
		end,
	},

	-- Codeium
	-- {
	-- 	"Exafunction/codeium.nvim",
	-- 	dependencies = { "nvim-lua/plenary.nvim", "hrsh7th/nvim-cmp" },
	-- 	cond = not vim.g.vscode,
	-- 	config = function()
	-- 		require("codeium").setup({})
	-- 	end,
	-- },
}
