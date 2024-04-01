return {
	"stevearc/conform.nvim",
	opts = {
		formatters_by_ft = {
			["lua"] = { "stylua" },
			["python"] = { "ruff_fix", "ruff_format", "black" },
			["go"] = { "gofmt" },
			["rust"] = { "rustfmt" },
			["typescript"] = { "prettier" },
			["javascript"] = { "prettier" },
			["typescriptreact"] = { "prettier" },
			["javascriptreact"] = { "prettier" },
		},
		-- formatters = { ruff_format = { command = vim.fn.expand("$HOME") .. "/tools/.venv/bin/ruff" } },
		format_on_save = {
			timout_ms = 500,
			lsp_fallback = true,
		},
	},
	init = function()
		require("conform").setup({
			format_on_save = function(bufnr)
				-- Disable with a global or buffer-local variable
				if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
					return
				end
				return { timeout_ms = 500, lsp_fallback = true }
			end,
		})

		vim.api.nvim_create_user_command("FormatDisable", function(args)
			if args.bang then
				-- FormatDisable! will disable formatting just for this buffer
				vim.b.disable_autoformat = true
			else
				vim.g.disable_autoformat = true
			end
		end, {
			desc = "Disable autoformat-on-save",
			bang = true,
		})
		vim.api.nvim_create_user_command("FormatEnable", function()
			vim.b.disable_autoformat = false
			vim.g.disable_autoformat = false
		end, {
			desc = "Re-enable autoformat-on-save",
		})
	end,
	-- config = function()
	-- 	local mason_reg = require("mason-registry")
	--
	-- 	local formatters = {}
	-- 	local formatters_by_ft = {}
	--
	--        local ruff_cmd=mason_reg.get_package("ruff").path
	--        vim.print(ruff_cmd)
	-- 	return {
	-- 		format_on_save = {
	-- 			lsp_fallback = true,
	-- 			timeout_ms = 500,
	-- 		},
	-- 		formatters = formatters,
	-- 		formatters_by_ft = formatters_by_ft,
	-- 	}
	-- end,
}
