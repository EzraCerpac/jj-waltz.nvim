local support = require('tests.support')

local M = {}

local function with_notify_capture(fn)
  local original = vim.notify
  local messages = {}

  vim.notify = function(message, level)
    table.insert(messages, { message = message, level = level })
  end

  local ok, err = xpcall(function()
    fn(messages)
  end, debug.traceback)

  vim.notify = original
  if not ok then
    error(err)
  end
end

local function with_ui_overrides(overrides, fn)
  local original_select = vim.ui.select
  local original_input = vim.ui.input

  if overrides.select then
    vim.ui.select = overrides.select
  end

  if overrides.input then
    vim.ui.input = overrides.input
  end

  local ok, err = xpcall(fn, debug.traceback)
  vim.ui.select = original_select
  vim.ui.input = original_input
  if not ok then
    error(err)
  end
end

local function setup_plugin(mock_command)
  support.reset_state()
  require('jj-waltz').setup({
    jw_cmd = mock_command,
    notify = true,
  })
end

function M.test_switch_retargets_cwd_and_reopens_current_buffer()
  local root = support.tempdir()
  local mock = support.mock_jw(root, {
    with_subdir = true,
    with_current_file = true,
  })

  setup_plugin(mock.command)
  vim.cmd.cd(vim.fn.fnameescape(support.join(mock.root, 'src')))
  vim.cmd.edit(vim.fn.fnameescape(support.join(mock.root, 'src', 'main.lua')))

  with_notify_capture(function()
    vim.cmd('JwSwitch feature-a')
  end)

  support.assert_path_eq(vim.fn.getcwd(), support.join(mock.feature_root, 'src'))
  support.assert_path_eq(
    vim.api.nvim_buf_get_name(0),
    support.join(mock.feature_root, 'src', 'main.lua')
  )
end

function M.test_switch_falls_back_to_workspace_root_when_subdir_missing()
  local root = support.tempdir()
  local mock = support.mock_jw(root, {
    with_subdir = false,
    with_current_file = false,
  })

  vim.fn.mkdir(support.join(mock.root, 'docs'), 'p')
  support.write(support.join(mock.root, 'docs', 'note.txt'), { 'default' })

  setup_plugin(mock.command)
  vim.cmd.cd(vim.fn.fnameescape(support.join(mock.root, 'docs')))
  vim.cmd.edit(vim.fn.fnameescape(support.join(mock.root, 'docs', 'note.txt')))

  with_notify_capture(function()
    vim.cmd('JwSwitch feature-a')
  end)

  support.assert_path_eq(vim.fn.getcwd(), mock.feature_root)
  support.assert_path_eq(vim.api.nvim_buf_get_name(0), support.join(mock.root, 'docs', 'note.txt'))
end

function M.test_picker_selection_uses_switch_flow()
  local root = support.tempdir()
  local mock = support.mock_jw(root, {
    with_subdir = true,
  })

  setup_plugin(mock.command)
  vim.cmd.cd(vim.fn.fnameescape(mock.root))

  with_ui_overrides({
    select = function(items, _, on_choice)
      for _, item in ipairs(items) do
        if item.kind == 'workspace' and item.target == 'feature-a' then
          on_choice(item, 1)
          return
        end
      end
      error('feature-a picker item not found')
    end,
  }, function()
    with_notify_capture(function()
      vim.cmd('JwPick')
    end)
  end)

  support.assert_path_eq(vim.fn.getcwd(), mock.feature_root)
end

function M.test_link_conflict_offers_follow_up_actions()
  local root = support.tempdir()
  local mock = support.mock_jw(root, {
    link_conflict = true,
  })

  setup_plugin(mock.command)
  vim.cmd.cd(vim.fn.fnameescape(mock.root))

  with_ui_overrides({
    select = function(items, _, on_choice)
      on_choice(items[1], 1)
    end,
  }, function()
    with_notify_capture(function(messages)
      vim.cmd('JwSwitch feature-a')
      local saw_conflict = false
      for _, entry in ipairs(messages) do
        if entry.message:find('Workspace links are blocking the switch', 1, true) then
          saw_conflict = true
          break
        end
      end
      support.assert_truthy(saw_conflict)
    end)
  end)

  local log = support.read(mock.log)
  support.assert_truthy(
    log:find('links repair', 1, true),
    'expected follow-up repair action to run'
  )
end

function M.test_explicit_links_repair_command_succeeds()
  local root = support.tempdir()
  local mock = support.mock_jw(root)

  setup_plugin(mock.command)
  vim.cmd.cd(vim.fn.fnameescape(mock.root))

  with_notify_capture(function(messages)
    vim.cmd('JwLinksRepair')
    support.assert_truthy(messages[#messages].message:find('Links: 1 repaired', 1, true))
  end)
end

return M
