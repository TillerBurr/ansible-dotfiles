return {
	{
		"stevearc/conform.nvim",
		opts = {
			formatters_by_ft = {
				lua = { "stylua" },
				python = { "ruff_fix", "ruff_format", "black" },
				go = { "gofmt" },
				rust = { "rustfmt" },
				typescript = { "prettier" },
				javascript = { "prettier" },
				typescriptreact = { "prettier" },
				javascriptreact = { "prettier" },
				markdown = { "mdformat" },
				sql = { "sqlfluff" },
			},
		},
	},
}
