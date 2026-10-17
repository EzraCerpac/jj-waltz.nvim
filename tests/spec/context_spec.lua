local actions = require('jj-waltz.actions')
local cli = require('jj-waltz.cli')
local support = require('tests.support')

local M = {}

local function setup()
  support.reset_state()
  local mock = support.mock_jw(support.tempdir(), {
    with_subdir = true,
    with_current_file = true,
  })
  require('jj-waltz').setup({ jw_cmd = mock.command, notify = false })
  vim.cmd.cd(vim.fn.fnameescape(mock.root))
  vim.cmd.edit(vim.fn.fnameescape(support.join(mock.root, 'src', 'main.lua')))
  return mock
end

local function switch(name)
  local result, err = actions.switch(name)
  support.assert_truthy(result, vim.inspect(err))
  return result
end

local function tab()
  return vim.api.nvim_get_current_tabpage()
end

local function windows()
  local result = {}
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    table.insert(result, {
      win = win,
      buffer = vim.api.nvim_win_get_buf(win),
      cursor = vim.api.nvim_win_get_cursor(win),
      view = vim.api.nvim_win_call(win, vim.fn.winsaveview),
    })
  end
  return result
end

function M.test_round_trips_restore_both_tabs_splits_cursors_and_focus()
  local mock = setup()
  local lines = {}
  for i = 1, 100 do
    table.insert(lines, ('line %d with text'):format(i))
  end
  support.write(support.join(mock.root, 'src', 'main.lua'), lines)
  support.write(support.join(mock.feature_root, 'src', 'main.lua'), lines)
  vim.cmd.edit()
  vim.cmd.vsplit()
  vim.api.nvim_win_set_cursor(0, { 50, 4 })
  vim.cmd('normal! zt')
  vim.cmd.split()
  vim.api.nvim_win_set_cursor(0, { 70, 7 })
  local source, source_win = tab(), vim.api.nvim_get_current_win()
  local source_layout, source_windows = vim.fn.winlayout(), windows()

  switch('feature-a')
  local target = tab()
  support.assert_truthy(target ~= source)
  support.assert_eq(vim.api.nvim_win_get_cursor(0), { 70, 7 })
  vim.cmd.split()
  vim.api.nvim_win_set_cursor(0, { 20, 3 })
  local target_win = vim.api.nvim_get_current_win()
  local target_layout, target_windows = vim.fn.winlayout(), windows()

  for _ = 1, 3 do
    switch('default')
    support.assert_eq(tab(), source)
    support.assert_eq(vim.api.nvim_get_current_win(), source_win)
    support.assert_eq(vim.fn.winlayout(), source_layout)
    support.assert_eq(windows(), source_windows)
    switch('feature-a')
    support.assert_eq(tab(), target)
    support.assert_eq(vim.api.nvim_get_current_win(), target_win)
    support.assert_eq(vim.fn.winlayout(), target_layout)
    support.assert_eq(windows(), target_windows)
    support.assert_eq(#vim.api.nvim_list_tabpages(), 2)
  end
end

function M.test_dirty_buffers_stay_in_source_with_nohidden_and_are_never_written()
  local mock = setup()
  local source, dirty = tab(), vim.api.nvim_get_current_buf()
  local path = vim.api.nvim_buf_get_name(dirty)
  local disk = support.read(path)
  local hidden = vim.o.hidden
  vim.o.hidden = false
  local ok, err = xpcall(function()
    vim.api.nvim_buf_set_lines(dirty, 0, -1, false, { 'unsaved source' })
    vim.bo.bufhidden = 'wipe'
    switch('feature-a')
    support.assert_eq(vim.api.nvim_buf_get_name(0), '')
    support.assert_truthy(vim.bo[dirty].modified)
    support.assert_eq(vim.api.nvim_buf_get_name(dirty), path)
    support.assert_eq(support.read(path), disk)
    support.assert_eq(vim.api.nvim_win_get_buf(vim.api.nvim_tabpage_get_win(source)), dirty)
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'unsaved target scratch' })
    local scratch = vim.api.nvim_get_current_buf()
    switch('default')
    support.assert_eq(vim.api.nvim_get_current_buf(), dirty)
    support.assert_eq(vim.api.nvim_buf_get_lines(dirty, 0, -1, false), { 'unsaved source' })
    switch('feature-a')
    support.assert_eq(vim.api.nvim_get_current_buf(), scratch)
    support.assert_truthy(vim.bo[scratch].modified)
  end, debug.traceback)
  vim.o.hidden = hidden
  support.assert_truthy(ok, err)
  support.assert_path_eq(vim.fn.getcwd(), mock.feature_root)
end

function M.test_dirty_inactive_split_is_preserved_while_clean_file_maps()
  local mock = setup()
  local source = tab()
  vim.cmd.vsplit()
  vim.cmd.enew()
  local dirty = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(dirty, 0, -1, false, { 'unsaved scratch' })
  vim.cmd.wincmd('p')
  switch('feature-a')
  support.assert_path_eq(
    vim.api.nvim_buf_get_name(0),
    support.join(mock.feature_root, 'src', 'main.lua')
  )
  switch('default')
  support.assert_eq(tab(), source)
  support.assert_truthy(vim.bo[dirty].modified)
  support.assert_eq(#vim.api.nvim_tabpage_list_wins(0), 2)
end

function M.test_missing_counterpart_starts_empty_and_deleted_open_file_survives()
  local mock = setup()
  local source, buffer = tab(), vim.api.nvim_get_current_buf()
  vim.fn.delete(support.join(mock.feature_root, 'src', 'main.lua'))
  switch('feature-a')
  support.assert_eq(vim.api.nvim_buf_get_name(0), '')
  vim.fn.delete(support.join(mock.root, 'src', 'main.lua'))
  switch('default')
  support.assert_eq(tab(), source)
  support.assert_eq(vim.api.nvim_get_current_buf(), buffer)
  support.assert_eq(vim.api.nvim_buf_get_lines(buffer, 0, -1, false), { "print('default')" })
end

function M.test_cwd_scopes_and_unrelated_tabs_are_preserved()
  local mock = setup()
  local source = tab()
  vim.cmd.tabnew()
  local unrelated = tab()
  vim.api.nvim_set_current_tabpage(source)
  vim.cmd.tcd(vim.fn.fnameescape(mock.root))
  vim.cmd.vsplit()
  local local_win = vim.api.nvim_get_current_win()
  vim.cmd.lcd(vim.fn.fnameescape(support.join(mock.root, 'src')))
  switch('feature-a')
  support.assert_path_eq(vim.fn.getcwd(), support.join(mock.feature_root, 'src'))
  support.assert_eq(vim.fn.haslocaldir(-1, 0), 1)
  support.assert_path_eq(vim.fn.getcwd(-1, -1), mock.root)
  vim.cmd.lcd(vim.fn.fnameescape(mock.feature_root))
  switch('default')
  support.assert_eq(vim.api.nvim_get_current_win(), local_win)
  support.assert_eq(vim.fn.haslocaldir(), 1)
  support.assert_path_eq(vim.fn.getcwd(), support.join(mock.root, 'src'))
  support.assert_path_eq(vim.fn.getcwd(-1, 0), mock.root)
  switch('feature-a')
  support.assert_eq(vim.fn.haslocaldir(), 1)
  support.assert_path_eq(vim.fn.getcwd(), mock.feature_root)
  vim.api.nvim_set_current_tabpage(unrelated)
  support.assert_path_eq(vim.fn.getcwd(), mock.root)
  support.assert_eq(vim.fn.haslocaldir(), 0)
end

function M.test_aliases_same_root_and_closed_tabs_do_not_create_duplicates()
  setup()
  local source = tab()
  switch('default')
  support.assert_eq(tab(), source)
  support.assert_eq(#vim.api.nvim_list_tabpages(), 1)
  switch('feature-a')
  local target = tab()
  switch('default')
  switch('-')
  support.assert_eq(tab(), target)
  vim.cmd.tabclose()
  switch('feature-a')
  support.assert_truthy(tab() ~= target)
  support.assert_eq(#vim.api.nvim_list_tabpages(), 2)
end

function M.test_manually_retargeted_tab_is_detached_without_losing_its_edits()
  local mock = setup()
  local source = tab()
  switch('feature-a')
  local target = tab()
  vim.api.nvim_set_current_tabpage(source)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'keep source edits' })
  local dirty = vim.api.nvim_get_current_buf()
  vim.cmd.tcd(vim.fn.fnameescape(mock.feature_root))
  vim.api.nvim_set_current_tabpage(target)
  switch('default')
  support.assert_truthy(tab() ~= source)
  support.assert_path_eq(vim.fn.getcwd(), mock.root)
  support.assert_path_eq(cli.run({ 'root' }), mock.root)
  support.assert_truthy(vim.api.nvim_tabpage_is_valid(source))
  support.assert_truthy(vim.bo[dirty].modified)
  support.assert_eq(vim.api.nvim_buf_get_lines(dirty, 0, -1, false), { 'keep source edits' })
  local fresh_source = tab()
  switch('feature-a')
  switch('default')
  support.assert_eq(tab(), fresh_source)
  support.assert_eq(#vim.api.nvim_list_tabpages(), 3)
end

function M.test_renamed_workspace_at_same_path_reuses_tab_but_moved_path_does_not()
  local mock = setup()
  switch('feature-a')
  local target = tab()
  switch('default')
  local original = cli.run
  local moved = support.join(mock.root, '..', 'moved')
  vim.fn.mkdir(moved, 'p')
  cli.run = function(args, opts)
    if args[1] == 'switch' and args[2] == 'renamed' then
      return mock.feature_root
    end
    if args[1] == 'switch' and args[2] == 'moved' then
      return moved
    end
    if args[1] == 'root' and opts.cwd == moved then
      return moved
    end
    return original(args, opts)
  end
  local ok, err = xpcall(function()
    switch('renamed')
    support.assert_eq(tab(), target)
    switch('default')
    switch('moved')
    support.assert_truthy(tab() ~= target)
    support.assert_truthy(vim.api.nvim_tabpage_is_valid(target))
  end, debug.traceback)
  cli.run = original
  support.assert_truthy(ok, err)
end

function M.test_missing_workspace_does_not_change_tabs_or_dirty_buffers()
  local mock = setup()
  switch('feature-a')
  local target, buffer = tab(), vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { 'keep these edits' })
  switch('default')
  local source = tab()
  vim.fn.delete(mock.feature_root, 'rf')
  local result, err = actions.switch('feature-a')
  support.assert_eq(result, nil)
  support.assert_truthy(err)
  support.assert_eq(tab(), source)
  support.assert_eq(#vim.api.nvim_list_tabpages(), 2)
  support.assert_truthy(vim.api.nvim_tabpage_is_valid(target))
  support.assert_truthy(vim.bo[buffer].modified)
  support.assert_eq(vim.api.nvim_buf_get_lines(buffer, 0, -1, false), { 'keep these edits' })
end

function M.test_first_visit_clamps_cursor_and_preserves_loaded_destination_edits()
  local mock = setup()
  vim.api.nvim_win_set_cursor(0, { 1, 10 })
  support.write(support.join(mock.feature_root, 'src', 'main.lua'), { 'x' })
  switch('feature-a')
  support.assert_eq(vim.api.nvim_win_get_cursor(0), { 1, 0 })
  switch('default')
  local destination = vim.fn.bufadd(support.join(mock.fallback_root, 'src', 'main.lua'))
  support.write(support.join(mock.fallback_root, 'src', 'main.lua'), { 'disk' })
  vim.fn.bufload(destination)
  vim.api.nvim_buf_set_lines(destination, 0, -1, false, { 'unsaved destination' })
  switch('feature-b')
  support.assert_eq(vim.api.nvim_get_current_buf(), destination)
  support.assert_truthy(vim.bo[destination].modified)
  support.assert_eq(
    vim.api.nvim_buf_get_lines(destination, 0, -1, false),
    { 'unsaved destination' }
  )
end

return M
