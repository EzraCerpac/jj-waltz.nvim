local M = {}

local sep = package.config:sub(1, 1)

local function shell_escape(value)
  return "'" .. tostring(value):gsub("'", [['"'"']]) .. "'"
end

function M.tempdir()
  local path = vim.fn.tempname()
  vim.fn.mkdir(path, 'p')
  return vim.uv.fs_realpath(path) or path
end

function M.write(path, lines)
  vim.fn.mkdir(vim.fn.fnamemodify(path, ':h'), 'p')
  vim.fn.writefile(type(lines) == 'table' and lines or { lines }, path)
end

function M.read(path)
  return table.concat(vim.fn.readfile(path), '\n')
end

function M.join(...)
  local parts = { ... }
  return table.concat(parts, sep)
end

function M.make_file(path, content)
  M.write(path, content)
end

function M.make_executable(path)
  vim.fn.system({ 'chmod', '+x', path })
end

function M.mock_jw(root, opts)
  opts = opts or {}
  local script = M.join(root, 'mock-jw.sh')
  local default_root = M.join(root, 'repo')
  local feature_root = M.join(root, 'repo.feature-a')
  local fallback_root = M.join(root, 'repo.feature-b')
  local log_path = M.join(root, 'jw.log')

  vim.fn.mkdir(default_root, 'p')
  vim.fn.mkdir(feature_root, 'p')
  vim.fn.mkdir(fallback_root, 'p')

  if opts.with_subdir then
    vim.fn.mkdir(M.join(default_root, 'src'), 'p')
    vim.fn.mkdir(M.join(feature_root, 'src'), 'p')
  end

  if opts.with_current_file then
    M.write(M.join(default_root, 'src', 'main.lua'), { "print('default')" })
    M.write(M.join(feature_root, 'src', 'main.lua'), { "print('feature')" })
  end

  if opts.fallback_file then
    M.write(M.join(default_root, 'docs', 'note.txt'), { 'default' })
  end

  local lines = {
    '#!/usr/bin/env bash',
    'set -euo pipefail',
    'ROOT=' .. shell_escape(root),
    'LOG=' .. shell_escape(log_path),
    'DEFAULT_ROOT=' .. shell_escape(default_root),
    'FEATURE_ROOT=' .. shell_escape(feature_root),
    'FALLBACK_ROOT=' .. shell_escape(fallback_root),
    'printf "%s\\n" "$*" >> "$LOG"',
    'if [[ $# -eq 1 && $1 == --help ]]; then',
    "  cat <<'EOF'",
    'Jujutsu workspace switching',
    '',
    'Usage: jw <COMMAND>',
    '',
    'Commands:',
    '  switch       Switch to or create a workspace',
    '  list         List known workspaces',
    '  path         Print a workspace path',
    '  remove       Forget a workspace',
    '  prune        Forget missing workspaces',
    '  root         Print the current workspace root',
    '  current      Print the current workspace name',
    '  shell        Shell integration helpers',
    '  links        Manage workspace links',
    '  completions  Generate shell completions',
    'EOF',
    '  exit 0',
    'fi',
    'if [[ $# -eq 2 && $1 == switch && $2 == --help ]]; then',
    "  cat <<'EOF'",
    'Switch to or create a workspace',
    '',
    'Usage: jw switch <NAME> [OPTIONS]',
    '',
    'Options:',
    '  --at <REVSET>',
    '  --bookmark <BOOKMARK>',
    '  --print-path',
    '  --no-links',
    'EOF',
    '  exit 0',
    'fi',
    'workspace_name() {',
    '  case "$1" in',
    '    "$FEATURE_ROOT"*) printf \'%s\' feature-a ;;',
    '    "$FALLBACK_ROOT"*) printf \'%s\' feature-b ;;',
    "    *) printf '%s' default ;;",
    '  esac',
    '}',
    'workspace_root() {',
    '  case "$1" in',
    '    "$FEATURE_ROOT"*) printf \'%s\' "$FEATURE_ROOT" ;;',
    '    "$FALLBACK_ROOT"*) printf \'%s\' "$FALLBACK_ROOT" ;;',
    '    *) printf \'%s\' "$DEFAULT_ROOT" ;;',
    '  esac',
    '}',
    'if [[ $# -eq 1 && $1 == list ]]; then',
    '  printf \'@ default\\t%s\\n\' "$DEFAULT_ROOT"',
    '  printf \'  feature-a\\t%s\\n\' "$FEATURE_ROOT"',
    '  printf \'^ feature-b\\t%s\\n\' "$FALLBACK_ROOT"',
    '  exit 0',
    'fi',
    'if [[ $# -eq 1 && $1 == root ]]; then',
    '  workspace_root "$PWD"',
    "  printf '\\n'",
    '  exit 0',
    'fi',
    'if [[ $# -eq 1 && $1 == current ]]; then',
    '  workspace_name "$PWD"',
    "  printf '\\n'",
    '  exit 0',
    'fi',
    'if [[ $# -ge 2 && $1 == path ]]; then',
    '  case "$2" in',
    '    @|default) printf \'%s\\n\' "$DEFAULT_ROOT" ;;',
    '    -|feature-a) printf \'%s\\n\' "$FEATURE_ROOT" ;;',
    '    ^|feature-b) printf \'%s\\n\' "$FALLBACK_ROOT" ;;',
    '    *) printf \'%s\\n\' "$ROOT/repo.$2" ;;',
    '  esac',
    '  exit 0',
    'fi',
    'if [[ $# -ge 1 && $1 == prune ]]; then',
    "  printf 'Pruned 0 workspace(s)\\n'",
    '  exit 0',
    'fi',
    'if [[ $# -ge 1 && $1 == remove ]]; then',
    '  printf \'Forgot workspace: %s\\n\' "${*: -1}"',
    '  exit 0',
    'fi',
    'if [[ $# -ge 2 && $1 == links ]]; then',
    '  if [[ $2 == apply ]]; then',
    "    printf 'Links: 0 repaired, 1 created, 0 already satisfied, 0 missing target\\n'",
    '    exit 0',
    '  fi',
    '  if [[ $2 == repair ]]; then',
    "    printf 'Links: 1 repaired, 0 created, 0 already satisfied, 0 missing target\\n'",
    '    exit 0',
    '  fi',
    'fi',
  }

  if opts.link_conflict then
    table.insert(lines, 'if [[ $# -ge 1 && $1 == switch ]]; then')
    table.insert(
      lines,
      "  printf '%s\\n' 'link conflict at data: path exists and is not a symlink to /tmp/shared. Run `jw links repair` to migrate it.' >&2"
    )
    table.insert(lines, '  exit 1')
    table.insert(lines, 'fi')
  else
    vim.list_extend(lines, {
      'if [[ $# -ge 1 && $1 == switch ]]; then',
      '  target=${2:-default}',
      '  if [[ $target == @ ]]; then target=default; fi',
      '  if [[ $target == - ]]; then target=feature-a; fi',
      '  if [[ $target == ^ ]]; then target=feature-b; fi',
      '  case "$target" in',
      '    default) target_root="$DEFAULT_ROOT" ;;',
      '    feature-a) target_root="$FEATURE_ROOT" ;;',
      '    feature-b) target_root="$FALLBACK_ROOT" ;;',
      '    *) target_root="$ROOT/repo.$target"; mkdir -p "$target_root" ;;',
      '  esac',
      '  current_root="$(workspace_root "$PWD")"',
      '  relative="${PWD#"$current_root"}"',
      '  relative="${relative#/}"',
      '  destination="$target_root"',
      '  if [[ -n "$relative" && -d "$target_root/$relative" ]]; then',
      '    destination="$target_root/$relative"',
      '  fi',
      '  printf "%s\\n" "$destination"',
      '  exit 0',
      'fi',
    })
  end

  table.insert(lines, "printf '%s\\n' 'unsupported mock invocation' >&2")
  table.insert(lines, 'exit 1')

  M.write(script, lines)
  M.make_executable(script)

  return {
    command = script,
    root = default_root,
    feature_root = feature_root,
    fallback_root = fallback_root,
    log = log_path,
  }
end

function M.assert_eq(actual, expected, message)
  if not vim.deep_equal(actual, expected) then
    error(
      (message or 'assertion failed')
        .. ('\nexpected: %s\nactual: %s'):format(vim.inspect(expected), vim.inspect(actual))
    )
  end
end

function M.assert_truthy(value, message)
  if not value then
    error(message or 'expected truthy value')
  end
end

function M.reset_state()
  require('jj-waltz.config').reset()
  require('jj-waltz.cli').clear_cache()
end

function M.assert_path_eq(actual, expected, message)
  actual = vim.uv.fs_realpath(actual) or actual
  expected = vim.uv.fs_realpath(expected) or expected
  M.assert_eq(actual, expected, message)
end

return M
