local cli = require('jj-waltz.cli')
local support = require('tests.support')

local M = {}

function M.test_parse_workspace_list_markers()
  local entries = cli.parse_workspace_list(table.concat({
    '@ default\t/tmp/repo',
    '- feature-a\t/tmp/repo.feature-a',
    '^ feature-b\t/tmp/repo.feature-b',
    '  scratch\t/tmp/repo.scratch',
  }, '\n'))

  support.assert_eq(#entries, 4)
  support.assert_eq(entries[1].name, 'default')
  support.assert_truthy(entries[1].is_current)
  support.assert_truthy(entries[2].is_previous)
  support.assert_truthy(entries[3].is_default)
  support.assert_eq(entries[4].marker, ' ')
end

function M.test_build_switch_args()
  local args = cli.build_switch_args('feature-a', {
    at = '@-',
    bookmark = 'feature-a',
    no_links = true,
    print_path = true,
  })

  support.assert_eq(args, {
    'switch',
    'feature-a',
    '--at',
    '@-',
    '--bookmark',
    'feature-a',
    '--no-links',
    '--print-path',
  })
end

function M.test_parse_capabilities()
  local capabilities = cli.parse_capabilities('Commands:\n  links', 'Options:\n  -h, --help')
  support.assert_truthy(capabilities.links)
  support.assert_eq(capabilities.print_path, false)
end

function M.test_friendly_error_messages()
  local unsupported = cli.friendly_error({
    code = 1,
    stderr = "error: unexpected argument '--print-path'",
  })
  local conflict = cli.friendly_error({
    code = 1,
    stderr = 'link conflict at data: existing path',
  })
  local missing = cli.friendly_error({
    code = 127,
    stderr = 'jw: command not found',
  })

  support.assert_eq(unsupported.kind, 'unsupported')
  support.assert_eq(conflict.kind, 'link_conflict')
  support.assert_eq(missing.kind, 'missing_executable')
end

return M
