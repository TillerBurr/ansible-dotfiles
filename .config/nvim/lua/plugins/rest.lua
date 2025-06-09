return {
  "rest-nvim/rest.nvim",
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    opts = function (_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      table.insert(opts.ensure_installed, "http")
    end,
  },		main = 'rest-nvim',
		ft = 'http',
		cmd = 'Rest',
		keys = {
			{ '<Leader>rr', '<cmd>Rest run<CR>', desc = 'Execute HTTP request' },
            { '<Leader>rl', '<cmd>Rest logs<CR>', desc = 'Preview last HTTP request' },
		},
}
