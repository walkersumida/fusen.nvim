-- Minimal init for test environment
local plenary_dir = os.getenv("PLENARY_DIR") or "/tmp/plenary.nvim"
vim.opt.rtp:append(".")
vim.opt.rtp:append(plenary_dir)
vim.cmd("runtime plugin/plenary.vim")
require("plenary.busted")

