vim.api.nvim_create_user_command("LspLogClear", function()
  local log_path = vim.lsp.get_log_path()
  -- Close the log buffer if it's open
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(bufnr) == log_path then
      vim.api.nvim_buf_delete(bufnr, { force = true })
      break
    end
  end
  -- Delete the log file
  pcall(vim.loop.fs_unlink, log_path)
  vim.notify("LSP log cleared!", vim.log.levels.INFO)
end, {})
