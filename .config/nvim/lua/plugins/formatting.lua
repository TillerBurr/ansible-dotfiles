return {
	{
		"stevearc/conform.nvim",
          event = { "BufWritePre" },
  cmd = { "ConformInfo" },
        keys = {
    {
      -- Customize or remove this keymap to your liking
      "<leader>f",
      function()
        require("conform").format({ async = true, lsp_fallback = true })
      end,
      mode = "",
      desc = "Format buffer",
    },
  },
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
