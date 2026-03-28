local cwd = vim.fn.getcwd()

vim.opt.runtimepath:prepend(cwd)
package.path = table.concat({
  cwd .. '/lua/?.lua',
  cwd .. '/lua/?/init.lua',
  cwd .. '/tests/?.lua',
  cwd .. '/tests/?/init.lua',
  package.path,
}, ';')

vim.opt.swapfile = false
vim.opt.hidden = true
