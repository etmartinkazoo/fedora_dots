local map = vim.keymap.set

map("n", "<leader>w", "<cmd>w<CR>", { desc = "Save" })
map("n", "<leader>q", "<cmd>q<CR>", { desc = "Quit" })
map("n", "<leader>e", vim.diagnostic.open_float, { desc = "Diagnostic" })
map("n", "<leader><leader>", function()
  vim.cmd("noh")
end, { desc = "Clear search" })
map("n", "j", "gj")
map("n", "k", "gk")
map("v", "<", "<gv")
map("v", ">", ">gv")
map("n", "<C-h>", "<C-w>h")
map("n", "<C-j>", "<C-w>j")
map("n", "<C-k>", "<C-w>k")
map("n", "<C-l>", "<C-w>l")

map("n", "<leader>tt", "<cmd>NvimTreeToggle<CR>", { desc = "Toggle tree" })

map("n", "<leader>ff", "<cmd>Telescope find_files<CR>", { desc = "Find files" })
map("n", "<leader>fg", "<cmd>Telescope live_grep<CR>", { desc = "Live grep" })
map("n", "<leader>fb", "<cmd>Telescope buffers<CR>", { desc = "Find buffers" })
map("n", "<leader>fh", "<cmd>Telescope help_tags<CR>", { desc = "Help tags" })
