vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("user.lsp", { clear = true }),
  callback = function(ev)
    local map = function(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = ev.buf, desc = desc })
    end

    -- Built-ins already cover grn/gra/grr/gri/grt, [d/]d, K, and insert-mode <C-s>.
    map("n", "gd", vim.lsp.buf.definition, "LSP definition")
    map("n", "<leader>rn", vim.lsp.buf.rename, "LSP rename")
    map("n", "<leader>ca", vim.lsp.buf.code_action, "LSP code action")
    map("n", "<leader>cf", function()
      vim.lsp.buf.format { async = true }
    end, "LSP format")
  end,
})

require("mason").setup()
require("mason-lspconfig").setup({
  ensure_installed = { "lua_ls", "ts_ls", "bashls" },
  automatic_enable = true,
})
