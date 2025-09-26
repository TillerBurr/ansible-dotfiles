-- CORRECTED version for lua/plugins/oil.lua
return {
    'stevearc/oil.nvim',
    opts = {},
    -- Optional dependencies
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
        -- First, set up the plugin
        require("oil").setup({})
        -- THEN, set the keymap
        vim.keymap.set("n", "-", "<CMD>Oil --float <CR>", { desc = "Open parent directory" })
    end,
    cond = not vim.g.vscode,
}
