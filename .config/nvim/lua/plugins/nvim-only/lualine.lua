return {
    'nvim-lualine/lualine.nvim',
    requires = {{ 'nvim-tree/nvim-web-devicons', opt = true }, 'ecthelionvi/NeoComposer.nvim'},
    config = function()
        require('lualine').setup({
            options = {
                theme = 'catppuccin',
                section_separators = { left = '', right = '' },
                component_separators = { left = '', right = '' }
            },
            sections = {
                lualine_c = {
                    { require('NeoComposer.ui').status_recording },
                },
            }

        })
    end
}
