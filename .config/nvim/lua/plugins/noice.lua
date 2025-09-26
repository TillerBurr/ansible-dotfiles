return {
  "folke/noice.nvim",
  event = "VeryLazy",
  dependencies = {
    "MunifTanjim/nui.nvim",
    -- nvim-notify is now a dependency, ensuring it loads for noice to use
    "rcarriga/nvim-notify",
  },
  config = function()
    -- Setup nvim-notify with your desired theme
    local notify = require("notify")
    notify.setup({
        stages = "fade_in_slide_out",
        timeout = 1500,
        background_colour = "#2E3440",
    })

    -- Setup noice
    require("noice").setup({
      -- This routes all notifications through the 'notify' view (from nvim-notify)
      routes = {
        {
          filter = { event = "notify" },
          view = "notify",
        },
      },
      lsp = {
        override = {
          ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
          ["vim.lsp.util.stylize_markdown"] = true,
          ["cmp.entry.get_documentation"] = true,
        },
      },
      presets = {
        bottom_search = true,
        command_palette = true,
        long_message_to_split = true,
        inc_rename = false,
        lsp_doc_border = false,
      },
    })

    -- Set the global vim.notify to use the nvim-notify backend
    vim.notify = notify
  end,
}
