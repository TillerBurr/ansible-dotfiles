
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
vim.print(lazypath)

if not vim.loop.fs_stat(lazypath) then
    vim.print("cloning lazy")
    vim.fn.system {
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable", -- latest stable release
        lazypath,
    }
end
vim.opt.rtp:prepend(lazypath)


require("lazy").setup("plugins",{
ui={border={ "┏", "━", "┓", "┃", "┛", "━", "┗", "┃" }}})

vim.keymap.set("n", "<leader>la", "<cmd>:Lazy<cr>")
