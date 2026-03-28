local M = {}

local modules = {
  'tests.spec.cli_spec',
  'tests.spec.integration_spec',
}

local function test_functions(module)
  local names = {}
  for name, value in pairs(module) do
    if type(value) == 'function' and name:match('^test_') then
      table.insert(names, name)
    end
  end
  table.sort(names)
  return names
end

function M.run()
  local total = 0
  local failures = {}

  for _, module_name in ipairs(modules) do
    local module = require(module_name)
    for _, test_name in ipairs(test_functions(module)) do
      total = total + 1
      local ok, err = xpcall(module[test_name], debug.traceback)
      if not ok then
        table.insert(failures, {
          module = module_name,
          test = test_name,
          error = err,
        })
      end
    end
  end

  if #failures > 0 then
    for _, failure in ipairs(failures) do
      vim.api.nvim_err_writeln(('%s :: %s\n%s'):format(failure.module, failure.test, failure.error))
    end
    vim.cmd.cquit(1)
    return
  end

  print(('jj-waltz.nvim tests passed (%d cases)'):format(total))
end

return M
