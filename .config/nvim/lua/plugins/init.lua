-- This file returns the final list of plugin specs for lazy.nvim

-- This table will hold the specs that lazy.nvim will load.
local specs = {
    -- This spec tells lazy.nvim to load all .lua files
    -- from the 'lua/plugins/always' directory.
    { import = "plugins.always" },
}

-- Conditionally add the correct directory based on the environment
if vim.g.vscode then
    -- We are in VSCode, so load VSCode-specific plugins
    -- (This directory 'lua/plugins/vscode-only' can be empty for now)
    table.insert(specs, { import = "plugins.vscode-only" })


else
    -- We are in terminal Neovim, so load nvim-only plugins
    -- from the 'lua/plugins/nvim-only' directory.
    table.insert(specs, { import = "plugins.nvim-only" })
end

-- Return the final list of specs to lazy.nvim
return specs
