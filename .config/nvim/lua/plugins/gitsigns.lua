return {
    "lewis6991/gitsigns.nvim",
    config = function()
        local gs = require("gitsigns")
        gs.setup {
            signs = {
                add = {  text = "+"},
                change = {  text = "~" },
                delete = { text = "_"},
                topdelete = { text = "‾", },
                changedelete = { text = "~",},
            },
            word_diff = false,

        }
    end

}
