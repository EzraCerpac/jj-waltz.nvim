local cli = require("jj-waltz.cli")
local config = require("jj-waltz.config")
local util = require("jj-waltz.util")

local M = {}

local function notify(message, level)
  util.notify(message, level, { enabled = config.get().notify })
end

local function show_error(err)
  if not err then
    return
  end

  notify(err.message, vim.log.levels.ERROR)

  if err.kind == "link_conflict" then
    vim.ui.select({
      { label = "Repair links", action = "repair" },
      { label = "Apply links", action = "apply" },
      { label = "Dismiss", action = "dismiss" },
    }, {
      prompt = "Workspace links need attention",
      format_item = function(item)
        return item.label
      end,
    }, function(choice)
      if not choice or choice.action == "dismiss" then
        return
      end

      if choice.action == "repair" then
        M.links_repair()
      elseif choice.action == "apply" then
        M.links_apply()
      end
    end)
  end
end

local function capture_buffer_state()
  return {
    path = util.normalize(vim.api.nvim_buf_get_name(0)),
    modified = vim.bo.modified,
  }
end

local function resolve_current_root()
  local root, err = cli.run({ "root" }, { context = { kind = "root" } })
  if not root then
    return nil, err
  end
  return util.normalize(root)
end

local function maybe_reopen_buffer(buffer_state, old_root, new_root)
  if not buffer_state.path or buffer_state.path == "" then
    return false
  end

  if buffer_state.modified then
    notify("Skipped reopening the current buffer because it has unsaved changes.", vim.log.levels.WARN)
    return false
  end

  local relative = util.relative_to(buffer_state.path, old_root)
  if relative == nil or relative == "" then
    return false
  end

  local candidate = util.join(new_root, relative)
  if not util.exists(candidate) then
    return false
  end

  vim.cmd.edit(vim.fn.fnameescape(candidate))
  return true
end

local function retarget_editor(destination, old_root, buffer_state)
  local target_root, err = cli.run({ "root" }, {
    cwd = destination,
    context = { kind = "root" },
  })
  if not target_root then
    return nil, err
  end

  vim.cmd.cd(vim.fn.fnameescape(destination))
  maybe_reopen_buffer(buffer_state, old_root, util.normalize(target_root))
  return util.normalize(target_root)
end

local function run_simple(args, opts)
  local output, err = cli.run(args, opts)
  if not output then
    show_error(err)
    return nil, err
  end
  return output
end

function M.current()
  local output = run_simple({ "current" }, { context = { kind = "current" } })
  if output then
    notify(output)
  end
  return output
end

function M.root()
  local output = run_simple({ "root" }, { context = { kind = "root" } })
  if output then
    notify(output)
  end
  return output
end

function M.path(name)
  local output = run_simple({ "path", name }, { context = { kind = "path" } })
  if output then
    notify(output)
  end
  return output
end

function M.remove(name, keep_dir)
  local output = run_simple(cli.build_remove_args(name, keep_dir), { context = { kind = "remove" } })
  if output then
    notify(output)
  end
  return output
end

function M.prune()
  local output = run_simple({ "prune" }, { context = { kind = "prune" } })
  if output then
    notify(output)
  end
  return output
end

function M.links_apply()
  local _, err = cli.ensure_capabilities({ links = true })
  if err then
    show_error(err)
    return nil, err
  end

  local output = run_simple({ "links", "apply" }, { context = { kind = "links" } })
  if output then
    notify(output)
  end
  return output
end

function M.links_repair()
  local _, err = cli.ensure_capabilities({ links = true })
  if err then
    show_error(err)
    return nil, err
  end

  local output = run_simple({ "links", "repair" }, { context = { kind = "links" } })
  if output then
    notify(output)
  end
  return output
end

function M.switch(name, opts)
  opts = opts or {}

  local old_root, root_err = resolve_current_root()
  if not old_root then
    show_error(root_err)
    return nil, root_err
  end

  local _, cap_err = cli.ensure_capabilities({ print_path = true })
  if cap_err then
    show_error(cap_err)
    return nil, cap_err
  end

  local buffer_state = capture_buffer_state()
  local destination, switch_err = cli.run(cli.build_switch_args(name, {
    at = opts.at,
    bookmark = opts.bookmark,
    no_links = opts.no_links,
    print_path = true,
  }), {
    context = { kind = "switch" },
  })

  if not destination then
    show_error(switch_err)
    return nil, switch_err
  end

  local target_root, retarget_err = retarget_editor(util.normalize(destination), old_root, buffer_state)
  if not target_root then
    show_error(retarget_err)
    return nil, retarget_err
  end

  notify(("Switched to %s\n%s"):format(name, destination))
  return {
    destination = util.normalize(destination),
    root = target_root,
  }
end

local function prompt_new_workspace()
  vim.ui.input({ prompt = "Workspace name: " }, function(name)
    name = util.trim(name or "")
    if name == "" then
      return
    end

    vim.ui.input({ prompt = "Revision for --at (optional): " }, function(revision)
      vim.ui.input({ prompt = "Bookmark for --bookmark (optional): " }, function(bookmark)
        M.switch(name, {
          at = util.trim(revision or ""),
          bookmark = util.trim(bookmark or ""),
        })
      end)
    end)
  end)
end

function M.pick()
  local output, err = cli.run({ "list" }, { context = { kind = "list" } })
  if not output then
    show_error(err)
    return nil, err
  end

  local entries = cli.parse_workspace_list(output)
  local items = {
    { kind = "quick", target = "@", label = "@ current workspace" },
    { kind = "quick", target = "-", label = "- previous workspace" },
    { kind = "quick", target = "^", label = "^ default workspace" },
    { kind = "quick", target = "default", label = "default workspace token" },
  }

  for _, entry in ipairs(entries) do
    local prefix = entry.marker ~= " " and (entry.marker .. " ") or "  "
    table.insert(items, {
      kind = "workspace",
      target = entry.name,
      label = ("%s%s  %s"):format(prefix, entry.name, entry.path),
    })
  end

  table.insert(items, {
    kind = "new",
    label = "+ create or switch workspace...",
  })

  vim.ui.select(items, {
    prompt = "jj-waltz workspaces",
    format_item = function(item)
      return item.label
    end,
  }, function(choice)
    if not choice then
      return
    end

    if choice.kind == "new" then
      prompt_new_workspace()
      return
    end

    M.switch(choice.target)
  end)

  return items
end

return M
