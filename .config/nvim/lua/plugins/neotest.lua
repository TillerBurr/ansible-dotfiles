return {
	"nvim-neotest/neotest",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"antoinemadec/FixCursorHold.nvim",
		"nvim-treesitter/nvim-treesitter",
		"nvim-neotest/neotest-python",
		"folke/neodev.nvim", -- Dependency is still needed
	},
	config = function()
		require("neotest").setup({
			adapters = {
				require("neotest-python")({
					dap = { justMyCode = false },
					python = ".venv/bin/python",
					runner = "pytest",
				}),
			},
		})
		vim.keymap.set("n", "<leader>dS", '<cmd>lua require("neotest").summary.toggle()<cr>')
		vim.keymap.set("n", "<leader>dm", '<cmd>lua require("neotest").run.run()<cr>')
		vim.keymap.set("n", "<leader>dM", '<cmd>lua require("neotest").run.run({strategy = "dap"})<cr>')
		vim.keymap.set("n", "<leader>dk", '<cmd>lua require("neotest").run.run({vim.fn.expand("%")})<cr>')
		vim.keymap.set(
			"n",
			"<leader>dK",
			'<cmd>lua require("neotest").run.run({vim.fn.expand("%"),strategy = "dap"})<cr>'
		)
		-- The redundant neodev.setup() call has been removed from here.
	end,
}
