local actions = require('jj-waltz.actions')

local M = {}

local registered = false

local function register(name, spec)
  vim.api.nvim_create_user_command(name, spec.callback, {
    nargs = spec.nargs or 0,
    desc = spec.desc,
    complete = spec.complete,
  })
end

function M.register()
  if registered then
    return
  end

  register('JwPick', {
    desc = 'Pick a jj-waltz workspace',
    callback = function()
      actions.pick()
    end,
  })

  register('JwSwitch', {
    nargs = 1,
    desc = 'Switch to a jj-waltz workspace',
    callback = function(params)
      actions.switch(params.args)
    end,
  })

  register('JwCurrent', {
    desc = 'Show the current jj-waltz workspace',
    callback = function()
      actions.current()
    end,
  })

  register('JwRoot', {
    desc = 'Show the current jj-waltz workspace root',
    callback = function()
      actions.root()
    end,
  })

  register('JwPath', {
    nargs = 1,
    desc = 'Show the path for a jj-waltz workspace',
    callback = function(params)
      actions.path(params.args)
    end,
  })

  register('JwRemove', {
    nargs = '?',
    desc = 'Forget a jj-waltz workspace',
    callback = function(params)
      actions.remove(params.args ~= '' and params.args or nil, false)
    end,
  })

  register('JwRemoveKeepDir', {
    nargs = '?',
    desc = 'Forget a jj-waltz workspace but keep its directory',
    callback = function(params)
      actions.remove(params.args ~= '' and params.args or nil, true)
    end,
  })

  register('JwPrune', {
    desc = 'Forget missing jj-waltz workspaces',
    callback = function()
      actions.prune()
    end,
  })

  register('JwLinksApply', {
    desc = 'Apply jj-waltz workspace links',
    callback = function()
      actions.links_apply()
    end,
  })

  register('JwLinksRepair', {
    desc = 'Repair jj-waltz workspace links',
    callback = function()
      actions.links_repair()
    end,
  })

  registered = true
end

return M
