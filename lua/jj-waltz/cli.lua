local config = require('jj-waltz.config')
local util = require('jj-waltz.util')

local M = {}

local capabilities_cache = {}

local function cache_key()
  return util.command_string(M.normalize_jw_cmd(config.get().jw_cmd))
end

function M.normalize_jw_cmd(jw_cmd)
  if type(jw_cmd) == 'string' then
    return { vim.fn.expand(jw_cmd) }
  end

  if type(jw_cmd) == 'table' then
    return vim.deepcopy(jw_cmd)
  end

  error('jj-waltz.nvim: `jw_cmd` must be a string or argv table')
end

function M.parse_workspace_list(stdout)
  local entries = {}

  for raw_line in vim.gsplit(stdout or '', '\n', { plain = true, trimempty = true }) do
    local marker, name, path = raw_line:match('^(.)%s+([^\t]+)\t(.+)$')
    if marker and name and path then
      table.insert(entries, {
        marker = marker,
        name = util.trim(name),
        path = util.trim(path),
        is_current = marker == '@',
        is_previous = marker == '-',
        is_default = marker == '^',
      })
    end
  end

  return entries
end

function M.parse_capabilities(main_help, switch_help)
  return {
    links = (main_help or ''):find('%f[%a]links%f[%A]') ~= nil,
    print_path = (switch_help or ''):find('%-%-print%-path') ~= nil,
  }
end

function M.build_switch_args(name, opts)
  opts = opts or {}
  local args = { 'switch', name }

  if opts.at and opts.at ~= '' then
    table.insert(args, '--at')
    table.insert(args, opts.at)
  end

  if opts.bookmark and opts.bookmark ~= '' then
    table.insert(args, '--bookmark')
    table.insert(args, opts.bookmark)
  end

  if opts.no_links then
    table.insert(args, '--no-links')
  end

  if opts.print_path then
    table.insert(args, '--print-path')
  end

  return args
end

function M.build_remove_args(name, keep_dir)
  local args = { 'remove' }
  if keep_dir then
    table.insert(args, '--keep-dir')
  end
  if name and name ~= '' then
    table.insert(args, name)
  end
  return args
end

function M.friendly_error(result, context)
  local stderr = util.trim((result and result.stderr) or '')
  local code = result and result.code or 1
  context = context or {}

  if
    code == 127
    or stderr:find('command not found', 1, true)
    or stderr:find('not found', 1, true)
  then
    return {
      kind = 'missing_executable',
      message = 'Could not execute `jw`. Set `jw_cmd` to a valid jj-waltz binary, such as `~/.local/bin/jw`.',
      stderr = stderr,
      code = code,
    }
  end

  if
    stderr:find("unrecognized subcommand 'links'", 1, true)
    or stderr:find("unexpected argument '--print-path'", 1, true)
    or stderr:find("unexpected argument '--no-links'", 1, true)
  then
    return {
      kind = 'unsupported',
      message = 'This plugin needs a newer `jw` with `links` support and `switch --print-path`. Point `jw_cmd` at your local repo build, for example `~/.local/bin/jw`.',
      stderr = stderr,
      code = code,
    }
  end

  if stderr:find('link conflict', 1, true) then
    return {
      kind = 'link_conflict',
      message = 'Workspace links are blocking the switch. Run `:JwLinksRepair` to migrate the conflicting path or `:JwLinksApply` after fixing the target.',
      stderr = stderr,
      code = code,
    }
  end

  if stderr:find('required link target is missing', 1, true) then
    return {
      kind = 'missing_link_target',
      message = 'A required workspace link target is missing. Fix `.jwlinks.toml` or create the target, then retry `:JwLinksApply` or `:JwSwitch`.',
      stderr = stderr,
      code = code,
    }
  end

  if
    stderr:find('could not determine current workspace', 1, true)
    or stderr:find('failed to execute `jj', 1, true)
    or stderr:find('workspace root', 1, true)
    or stderr:find('There is no jj repo', 1, true)
  then
    return {
      kind = 'not_in_workspace',
      message = 'jj-waltz.nvim needs to run inside a Jujutsu workspace.',
      stderr = stderr,
      code = code,
    }
  end

  return {
    kind = context.kind or 'command_failed',
    message = stderr ~= '' and stderr or 'The `jw` command failed.',
    stderr = stderr,
    code = code,
  }
end

local function run_raw(args, opts)
  opts = opts or {}
  local command = M.normalize_jw_cmd(config.get().jw_cmd)
  vim.list_extend(command, args)

  local ok, proc = pcall(vim.system, command, {
    cwd = opts.cwd,
    text = true,
    env = opts.env,
  })

  if not ok then
    return nil, M.friendly_error({ code = 127, stderr = tostring(proc) }, opts.context)
  end

  local result = proc:wait()
  result.stdout = result.stdout or ''
  result.stderr = result.stderr or ''

  if result.code ~= 0 and not opts.allow_error then
    return nil, M.friendly_error(result, opts.context)
  end

  return result
end

function M.run(args, opts)
  local result, err = run_raw(args, opts)
  if not result then
    return nil, err
  end

  return util.trim(result.stdout), result
end

function M.detect_capabilities()
  local key = cache_key()
  if capabilities_cache[key] then
    return capabilities_cache[key]
  end

  local main_help, main_err = M.run({ '--help' }, { context = { kind = 'help' } })
  if not main_help then
    return nil, main_err
  end

  local switch_help, switch_err = M.run({ 'switch', '--help' }, { context = { kind = 'help' } })
  if not switch_help then
    return nil, switch_err
  end

  local capabilities = M.parse_capabilities(main_help, switch_help)
  capabilities_cache[key] = capabilities
  return capabilities
end

function M.probe_print_path_support()
  local result, err = run_raw({ 'switch', '@', '--print-path', '--no-links' }, {
    allow_error = true,
    context = { kind = 'probe' },
  })
  if not result then
    return nil, err
  end

  if result.code == 0 and util.trim(result.stdout) ~= '' then
    return true
  end

  local friendly = M.friendly_error(result, { kind = 'probe' })
  if friendly.kind == 'unsupported' then
    return false, friendly
  end

  return nil, friendly
end

function M.ensure_capabilities(required)
  required = required or {}
  local key = cache_key()
  local capabilities, err = M.detect_capabilities()
  if not capabilities then
    return nil, err
  end

  if required.links and not capabilities.links then
    return nil,
      M.friendly_error({
        code = 1,
        stderr = "unrecognized subcommand 'links'",
      }, { kind = 'unsupported' })
  end

  if required.print_path and not capabilities.print_path then
    local supported, probe_err = M.probe_print_path_support()
    if supported == nil then
      return nil, probe_err
    end

    capabilities.print_path = supported
    capabilities_cache[key] = capabilities

    if not capabilities.print_path then
      return nil,
        probe_err or M.friendly_error({
          code = 1,
          stderr = "unexpected argument '--print-path'",
        }, { kind = 'unsupported' })
    end
  end

  return capabilities
end

function M.clear_cache()
  capabilities_cache = {}
end

return M
