local cli = require('jj-waltz.cli')
local util = require('jj-waltz.util')

local M = {}

local root_var = 'jj_waltz_root'

local function root_key(root)
  return util.normalize(vim.uv.fs_realpath(root) or root)
end

local function find_tab(root)
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    local ok, value = pcall(vim.api.nvim_tabpage_get_var, tab, root_var)
    if ok and value == root then
      local win = vim.api.nvim_tabpage_get_win(tab)
      local cwd = vim.fn.getcwd(win, vim.api.nvim_tabpage_get_number(tab))
      local actual_root = cli.run({ 'root' }, { cwd = cwd, context = { kind = 'root' } })
      if actual_root and root_key(actual_root) == root then
        return tab
      end
      -- A manual cwd change can leave a tab tagged for another workspace.
      -- Detach it rather than reporting a switch into the wrong repository.
      vim.api.nvim_tabpage_del_var(tab, root_var)
    end
  end
end

function M.capture()
  return {
    tab = vim.api.nvim_get_current_tabpage(),
    path = util.normalize(vim.api.nvim_buf_get_name(0)),
    modified = vim.bo.modified,
    buftype = vim.bo.buftype,
    cursor = vim.api.nvim_win_get_cursor(0),
  }
end

local function open_relative(state, old_root, new_root)
  if state.modified then
    return 'Unsaved changes remain in the original workspace tab.'
  end
  if state.buftype ~= '' or state.path == '' then
    return
  end

  local relative = util.relative_to(state.path, old_root)
  if not relative or relative == '' then
    return
  end

  local candidate = util.join(new_root, relative)
  local stat = vim.uv.fs_stat(candidate)
  if not stat or stat.type ~= 'file' then
    return 'No matching file in the destination; opened an empty workspace tab.'
  end

  -- No reload or forced edit: an already loaded destination buffer keeps its edits.
  vim.cmd.edit(vim.fn.fnameescape(candidate))
  if not vim.bo.modified then
    local line = math.min(state.cursor[1], vim.api.nvim_buf_line_count(0))
    local text = vim.api.nvim_buf_get_lines(0, line - 1, line, false)[1] or ''
    vim.api.nvim_win_set_cursor(0, { line, math.min(state.cursor[2], #text) })
  end
end

function M.activate(state, old_root, new_root, destination)
  local old_key = root_key(old_root)
  local new_key = root_key(new_root)

  -- Adopt the source without changing any of its cwd scopes or windows.
  -- A manual :cd into another workspace changes the current tab's association.
  local ok, previous = pcall(vim.api.nvim_tabpage_get_var, state.tab, root_var)
  if ok and previous ~= old_key then
    vim.api.nvim_tabpage_del_var(state.tab, root_var)
  end
  if not find_tab(old_key) then
    vim.api.nvim_tabpage_set_var(state.tab, root_var, old_key)
  end

  local target = find_tab(new_key)
  if target then
    -- Native tabs retain the active window, split layout, views and local cwds.
    vim.api.nvim_set_current_tabpage(target)
    return
  end

  vim.cmd.tabnew()
  vim.cmd.tcd(vim.fn.fnameescape(destination))
  vim.api.nvim_tabpage_set_var(0, root_var, new_key)
  return open_relative(state, old_root, new_root)
end

return M
