return {
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
      "j-hui/fidget.nvim",
      "hrsh7th/cmp-nvim-lsp",
      "folke/noice.nvim"
    },
    config = function()
      -- Helper function to find the project root directory
      local function get_project_root()
        local current_file = vim.api.nvim_buf_get_name(0)
        if current_file == "" then return vim.fn.getcwd() end
        local current_dir = vim.fn.isdirectory(current_file) == 1 and current_file or vim.fn.fnamemodify(current_file, ":h")
        local root_markers = { ".git", "pyproject.toml", "setup.py", "requirements.txt" }
        local marker = vim.fs.find(root_markers, { path = current_dir, upward = true })[1]

        local root = vim.fn.getcwd() -- Default to current working directory
        if marker then
          root = vim.fn.fnamemodify(marker, ":h") -- Set root to the directory containing the marker
        end

        -- ✨ NOTIFY: Show the project root that was found
        vim.notify("LSP project root: " .. root, vim.log.levels.INFO, { title = "LSP" })
        return root
      end

      -- Helper function to find the Python executable in a virtual environment
      local function get_python_path()
        local root = get_project_root()
        local venv_names = { ".venv", "venv" }
        for _, name in ipairs(venv_names) do
          local python_executable = root .. "/" .. name .. "/bin/python"
          if vim.fn.filereadable(python_executable) == 1 then
            -- ✨ NOTIFY: Announce the found virtual environment
            vim.notify("Found Python venv: " .. python_executable, vim.log.levels.INFO, { title = "Pyright" })
            return python_executable
          end
        end

        -- ✨ NOTIFY: Announce the fallback to global python
        vim.notify("No venv found. Falling back to global 'python3'.", vim.log.levels.WARN, { title = "Pyright" })
        return "python3" -- Fallback to a global python
      end

      -- Keymaps and settings to apply to all LSP servers
      local on_attach = function(client, bufnr)
        local opts = { buffer = bufnr, noremap = true, silent = true }
        vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
        vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
        vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
        vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
        vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
        vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, opts)
        vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
        vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float, opts)

        if client.name == "pyright" then
          client.server_capabilities.documentFormattingProvider = false
        end
        if client.name == "ruff" then
          client.server_capabilities.hoverProvider = false
        end
      end

      -- Autocompletion capabilities
      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      -- Setup Mason and Fidget
      require("mason").setup()
      require("fidget").setup({})

      local servers = {
        "pyright",
        "ruff",
        "yamlls",
        "marksman",
        "lua_ls",
        "gopls",
      }

      require("mason-lspconfig").setup({
        ensure_installed = servers,
      })

      -- Loop through servers and configure them
      for _, server_name in ipairs(servers) do
        local server_opts = {
          on_attach = on_attach,
          capabilities = capabilities,
        }

        if server_name == "pyright" then
          server_opts.settings = {
            python = {
              pythonPath = get_python_path(),
            },
          }
        end

        if server_name == "lua_ls" then
          server_opts.settings = {
            Lua = {
              runtime = { version = "LuaJIT" },
              diagnostics = { globals = { "vim" } },
              workspace = {
                library = vim.api.nvim_get_runtime_file("", true),
                checkThirdParty = false,
              },
            },
          }
        end

        -- Use the new central vim.lsp.config function.
        vim.lsp.config(server_name, server_opts)

      end
    end,
  },
}
