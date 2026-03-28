local actions = require('jj-waltz.actions')
local commands = require('jj-waltz.commands')
local config = require('jj-waltz.config')

local M = {}

local function setup_keymaps(opts)
  if not opts.keymaps then
    return
  end

  vim.keymap.set('n', '<leader>jw', function()
    actions.pick()
  end, { desc = 'jj-waltz picker' })
end

function M.setup(opts)
  local resolved = config.setup(opts)
  commands.register()
  setup_keymaps(resolved)
  return resolved
end

return M
