local function set_transparent()
  vim.api.nvim_set_hl(0, "Normal", { bg = nil })
end

require("auto-dark-mode").setup({
  set_dark_mode = function()
    vim.opt.background = "dark"
    vim.cmd.colorscheme("default")
    set_transparent()
  end,
  set_light_mode = function()
    vim.opt.background = "light"
    vim.cmd.colorscheme("default")
    set_transparent()
  end,
})
