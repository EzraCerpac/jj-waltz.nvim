local M = {}

local defaults = {
  jw_cmd = 'jw',
  picker = 'vim_ui_select',
  switch_behavior = 'retarget',
  open_strategy = 'cwd',
  notify = true,
  keymaps = false,
}

local state = vim.deepcopy(defaults)

function M.defaults()
  return vim.deepcopy(defaults)
end

function M.get()
  return state
end

function M.setup(opts)
  state = vim.tbl_deep_extend('force', vim.deepcopy(defaults), opts or {})
  return state
end

function M.reset()
  state = vim.deepcopy(defaults)
end

return M
