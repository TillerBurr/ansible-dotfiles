-- TODO: break this into smaller modules
return {
	{
		"VonHeikemen/lsp-zero.nvim",
		branch = "v3.x",
        cond= not vim.g.vscode,
		dependencies = {
			-- LSP Support
			{
				"neovim/nvim-lspconfig",
				dependencies = { "folke/neoconf.nvim", cmd = "Neoconf", config = true },
				"rafi/neoconf-venom.nvim",
			},
			{
				"williamboman/mason.nvim",
				build = function()
					pcall(vim.cmd, "MasonUpdate")
				end,
				dependencies = {
					"williamboman/mason-lspconfig.nvim",
					{
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
								["markdown"] = { "mdformat" },
                                ["sql"] = { "sqlfluff"}
							},
						},
					},
					{
						"zbirenbaum/copilot-cmp",
						config = function()
							require("copilot_cmp").setup({})
						end,
						dependencies = {
							"zbirenbaum/copilot.lua",
							cmd = "Copilot",
							event = "InsertEnter",
							config = function()
								require("copilot").setup({
									suggestion = { enabled = false },
									panel = { enabled = false },
								})
							end,
						},
					},
				},
			},

			-- Autocompletion
			"hrsh7th/nvim-cmp",
			"hrsh7th/cmp-buffer",
			"hrsh7th/cmp-path",
			"hrsh7th/cmp-cmdline",
			"saadparwaiz1/cmp_luasnip",
			"hrsh7th/cmp-nvim-lsp",
			"hrsh7th/cmp-nvim-lsp-signature-help",
			"hrsh7th/cmp-nvim-lua",
			"lukas-reineke/cmp-under-comparator",
			"onsails/lspkind.nvim",

			-- Snippets
			"L3MON4D3/LuaSnip",
			"rafamadriz/friendly-snippets",
		},
		config = function()
			local has_words_before = function()
				if vim.api.nvim_buf_get_option(0, "buftype") == "prompt" then
					return false
				end
				local line, col = unpack(vim.api.nvim_win_get_cursor(0))
				return col ~= 0
					and vim.api.nvim_buf_get_text(0, line - 1, 0, line - 1, col, {})[1]:match("^%s*$") == nil
			end
			require("neoconf").setup()
			require("venom").setup()
			local lspconfig = require("lspconfig")
			local lsp_zero = require("lsp-zero")
			local capabilities = require("cmp_nvim_lsp").default_capabilities()
			lsp_zero.preset({
				manage_nvim_cmp = {
					set_basic_mappings = true,
				},
			})
			lsp_zero.set_preferences({
				suggest_lsp_servers = true,
				sign_icons = {
					error = "🆇",
					warn = "⚠️",
					hint = "ℹ️",
					info = "💡",
				},
			})

			local on_attach_no_format = function(client, _)
				client.server_capabilities.documentFormattingProvider = false
			end

			local luasnip = require("luasnip")
			local cmp = require("cmp")
			local lspkind = require("lspkind")
			require("luasnip.loaders.from_vscode").lazy_load()
			luasnip.setup({
				region_check_events = "CursorHold,InsertLeave",
				-- those are for removing deleted snippets, also a common problem
				delete_check_events = "TextChanged,InsertEnter",
			})

			cmp.setup({
				window = {
					completion = cmp.config.window.bordered(),
					documentation = cmp.config.window.bordered(),
				},
				mapping = {
					-- ["<CR>"] = cmp.mapping.confirm({ select = true }),
					["<CR>"] = cmp.mapping.confirm({
						-- documentation says this is important.
						-- I don't know why.
						behavior = cmp.ConfirmBehavior.Replace,
						select = false,
					}),
					["<C-n>"] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Insert }),
					["<C-p>"] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Insert }),
					["<C-d>"] = cmp.mapping.scroll_docs(-4),
					["<C-f>"] = cmp.mapping.scroll_docs(4),
					["<C-e>"] = cmp.mapping.abort(),
					["<c-y>"] = cmp.mapping(
						cmp.mapping.confirm({
							behavior = cmp.ConfirmBehavior.Insert,
							select = true,
						}),
						{ "i", "c" }
					),
					["<M-y>"] = cmp.mapping(
						cmp.mapping.confirm({
							behavior = cmp.ConfirmBehavior.Replace,
							select = false,
						}),
						{ "i", "c" }
					),

					["<C-Space>"] = cmp.mapping({
						i = cmp.mapping.complete(),
						c = function(
							_ --[[fallback]]
						)
							if cmp.visible() then
								if not cmp.confirm({ select = true }) then
									return
								end
							else
								cmp.complete()
							end
						end,
					}),
					["<Tab>"] = vim.schedule_wrap(function(fallback)
						if cmp.visible() and has_words_before() then
							cmp.select_next_item({ behavior = cmp.SelectBehavior.Select })
						elseif luasnip.expand_or_jumpable() then
							luasnip.expand_or_jump()
						else
							fallback()
						end
					end),
					["<S-Tab>"] = vim.schedule_wrap(function(fallback)
						if cmp.visible() and has_words_before() then
							cmp.select_prev_item({ behavior = cmp.SelectBehavior.Select })
						elseif luasnip.jumpable(-1) then
							luasnip.jump(-1)
						else
							fallback()
						end
					end),
				},
				sources = {
					{ name = "copilot", group_index = 2 },
					{ name = "nvim_lsp", group_index = 2 },
					{ name = "nvim_lua", group_index = 2 },
					{ name = "luasnip", group_index = 2 },
					{ name = "path", group_index = 2 }, -- for path completion
					{ name = "buffer", keyword_length = 2, group_index = 2 }, -- for buffer word completion
				},
				completion = {
					keyword_length = 1,
					completeopt = "menu,noselect",
				},
				experimental = {
					ghost_text = true,
				},
				formatting = {
					format = lspkind.cmp_format({
						mode = "symbol_text",
						ellipsis_char = "...",
						symbol_map = { Copilot = "" },
						menu = {
							nvim_lsp = "[LSP]",
							nvim_lua = "[Lua]",
							path = "[Path]",
							buffer = "[Buffer]",
							luasnip = "[Snip]",
						},
					}),
				},
				sorting = {
					comparators = {
                        require("copilot_cmp.comparators").prioritize,
						cmp.config.compare.offset,
						cmp.config.compare.exact,
						cmp.config.compare.score,
						require("cmp-under-comparator").under,
						cmp.config.compare.kind,
						cmp.config.compare.sort_text,
						cmp.config.compare.length,
						cmp.config.compare.order,
					},
				},
			})
			-- `/` cmdline setup.
			cmp.setup.cmdline("/", {
				mapping = cmp.mapping.preset.cmdline(),
				sources = {
					{ name = "buffer" },
				},
			})
			-- `:` cmdline setup.
			cmp.setup.cmdline(":", {
				mapping = cmp.mapping.preset.cmdline(),
				sources = cmp.config.sources({
					{ name = "path" },
				}, {
					{
						name = "cmdline",
						option = {
							ignore_cmds = { "Man", "!" },
						},
					},
				}),
			})
			lsp_zero.on_attach(function(_, bufnr)
				-- see :help lsp-zero-keybindings
				-- to learn the available actions
				local opts = function(description)
					return { buffer = bufnr, remap = false, desc = description }
				end
				local conform = require("conform")
				vim.keymap.set("n", "gd", function()
					vim.lsp.buf.definition()
				end, opts("definition"))
				vim.keymap.set("n", "gk", function()
					vim.lsp.buf.hover()
				end, opts("hover"))
				vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts("declaration"))
				vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts("implementation"))
				-- vim.keymap.set("n", "<leader>ws", function()
				-- 	vim.lsp.buf.workspace_symbol()
				-- end, opts("workspace symbol"))
				vim.keymap.set("n", "<leader>e", function()
					vim.diagnostic.open_float()
				end, opts("open float"))
				vim.keymap.set("n", "[d", function()
					vim.diagnostic.goto_next()
				end, opts("goto next"))
				vim.keymap.set("n", "]d", function()
					vim.diagnostic.goto_prev()
				end, opts("goto prev"))
				vim.keymap.set("n", "<leader>ca", function()
					vim.lsp.buf.code_action()
				end, opts("code action"))
				vim.keymap.set("n", "gr", function()
					vim.lsp.buf.references()
				end, opts("references"))
				vim.keymap.set("n", "<leader>rn", function()
					vim.lsp.buf.rename()
				end, opts("rename"))
				vim.keymap.set("i", "<C-h>", function()
					vim.lsp.buf.signature_help()
				end, opts("signature help"))
				vim.keymap.set("n", "<leader>f", function()
					-- vim.lsp.buf.format()
					conform.format()
				end, { desc = "format code" })
				-- vim.keymap.set("n", "<leader>f", function() require('conform').format()  end, { desc = "format code" })
				vim.keymap.set("n", "<leader>ll", vim.diagnostic.setloclist, opts("set loc list"))
				vim.api.nvim_buf_set_option(bufnr, "omnifunc", "v:lua.vim.lsp.omnifunc")

				vim.api.nvim_buf_set_option(bufnr, "omnifunc", "v:lua.vim.lsp.omnifunc")
				-- Enable completion triggered by <c-x><c-o>
				lsp_zero.default_keymaps({ buffer = bufnr })
			end)
			local ruff_on_attach = function(client, bufnr)
				vim.api.nvim_buf_set_option(bufnr, "omnifunc", "v:lua.vim.lsp.omnifunc")

				-- Mappings.
				-- See `:help vim.lsp.*` for documentation on any of the below functions
				local bufopts = { noremap = true, silent = true, buffer = bufnr }
				vim.keymap.set("n", "gD", vim.lsp.buf.declaration, bufopts)
				vim.keymap.set("n", "gi", vim.lsp.buf.implementation, bufopts)
				vim.keymap.set("n", "<leader>ra", vim.lsp.buf.add_workspace_folder, bufopts)
				vim.keymap.set("n", "<leader>rr", vim.lsp.buf.remove_workspace_folder, bufopts)
				vim.keymap.set("n", "<leader>rl", function()
					print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
				end, bufopts)
				vim.keymap.set("n", "<leader>D", vim.lsp.buf.type_definition, bufopts)
				-- vim.keymap.set('n', '<space>f', function() vim.lsp.buf.format { async = true } end, bufopts)
				client.server_capabilities.hoverProvider = false
				client.server_capabilities.signatureHelpProvider = false
			end
			require("mason").setup({})
			-- require("mason-conform").setup({ ensure_installed = { "ruff_fix", "ruff_format", "black", "prettier" }, quiet_mode = false })
			require("mason-lspconfig").setup({
				-- Replace the language servers listed here
				-- with the ones you want to install
				ensure_installed = {
					"ts_ls",
					"pyright",
					"yamlls",
					"marksman",
					"lua_ls",
					"rust_analyzer",
					"gopls",
				},
				handlers = {
					lsp_zero.default_setup,
					lua_ls = lspconfig.lua_ls.setup({ settings = { Lua = { diagnostics = { globals = { "vim" } } } } }),
					pyright = lspconfig.pyright.setup({
						on_attach = on_attach_no_format,
						capabilities = {
							textDocument = {
								publishDiagnostics = {
									tagSupport = {
										valueSet = { 2 },
									},
								},
							},
						},
						settings = {
							python = {
								analysis = {
									typeCheckingMode = "basic",
									diagnosticMode = "openFilesOnly",
								},
							},
						},
					}),
					ts_ls = lspconfig.ts_ls.setup({}),
					yamlls = function()
						lspconfig.yamlls.setup({
							settings = {
								yaml = {
									schemas = {
										["https://json.schemastore.org/github-workflow.json"] = "/.github/workflows/*",
										["https://squidfunk.github.io/mkdocs-material/schema.json"] = "mkdocs.yml",
									},
								},
							},
						})
					end,
					marksman = function()
						lspconfig.marksman.setup({})
					end,
					ruff_lsp = function()
						lspconfig.ruff_lsp.setup({ on_attach = ruff_on_attach })
					end,
					rust_analyzer = function()
						return true
						--     -- lspconfig.rust_analyzer.setup({})
						-- local codelldb = require('plugins.lsp.codelldb')
						-- require("rust-tools").setup(codelldb.opts)
						-- require("dap").adapters.codelldb = codelldb.adapter
					end,
					gopls = function()
						lspconfig.gopls.setup({})
					end,
				},
			})
		end,
	},
	{
		"mrcjkb/rustaceanvim",
		version = "^3", -- Recommended
        cond= not vim.g.vscode,
		ft = { "rust" },
		opts = {
			server = {
				on_attach = function(client, bufnr)
					-- register which-key mappings
					local wk = require("which-key")
					wk.register({
						["<leader>ca"] = {
							function()
								vim.cmd.RustLsp("codeAction")
							end,
							"Code Action",
						},
						["<leader>dr"] = {
							function()
								vim.cmd.RustLsp("debuggables")
							end,
							"Rust debuggables",
						},
					}, { mode = "n", buffer = bufnr })
				end,
				settings = {
					-- rust-analyzer language server configuration
					["rust-analyzer"] = {
						cargo = {
							allFeatures = true,
							loadOutDirsFromCheck = true,
							runBuildScripts = true,
						},
						-- Add clippy lints for Rust.
						checkOnSave = {
							allFeatures = true,
							command = "clippy",
							extraArgs = { "--no-deps" },
						},
						procMacro = {
							enable = true,
							ignored = {
								["async-trait"] = { "async_trait" },
								["napi-derive"] = { "napi" },
								["async-recursion"] = { "async_recursion" },
							},
						},
					},
				},
			},
		},
		config = function(_, opts)
			vim.g.rustaceanvim = vim.tbl_deep_extend("force", {}, opts or {})
		end,
	},
	{
        cond= not vim.g.vscode,
		"Exafunction/codeium.nvim",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"hrsh7th/nvim-cmp",
		},
		config = function()
			require("codeium").setup({})
		end,
	},
	{
		"rafi/neoconf-venom.nvim",
		dependencies = { "nvim-lua/plenary.nvim", "folke/neoconf.nvim" },
        cond= not vim.g.vscode,
	},
}
