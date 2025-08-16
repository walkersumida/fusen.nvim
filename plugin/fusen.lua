if vim.fn.has("nvim-0.7.0") == 0 then
  vim.api.nvim_err_writeln("fusen.nvim requires at least nvim-0.7.0")
  return
end

if vim.g.loaded_fusen == 1 then
  return
end
vim.g.loaded_fusen = 1
