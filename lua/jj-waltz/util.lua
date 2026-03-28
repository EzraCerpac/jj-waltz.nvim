local M = {}

local sep = package.config:sub(1, 1)
local unpack_fn = table.unpack or unpack

function M.trim(value)
  return (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

function M.join(...)
  local parts = { ... }
  if vim.fs and vim.fs.joinpath then
    return vim.fs.joinpath(unpack_fn(parts))
  end

  return table.concat(parts, sep)
end

function M.normalize(path)
  if not path or path == "" then
    return path
  end

  if vim.fs and vim.fs.normalize then
    return vim.fs.normalize(path)
  end

  return path
end

function M.is_descendant(path, root)
  path = M.normalize(path)
  root = M.normalize(root)
  if not path or not root then
    return false
  end

  if path == root then
    return true
  end

  local prefix = root
  if not prefix:match(sep .. "$") then
    prefix = prefix .. sep
  end

  return path:sub(1, #prefix) == prefix
end

function M.relative_to(path, root)
  path = M.normalize(path)
  root = M.normalize(root)
  if not M.is_descendant(path, root) then
    return nil
  end

  if path == root then
    return ""
  end

  local prefix = root
  if not prefix:match(sep .. "$") then
    prefix = prefix .. sep
  end

  return path:sub(#prefix + 1)
end

function M.exists(path)
  return path and vim.uv.fs_stat(path) ~= nil
end

function M.notify(message, level, opts)
  opts = opts or {}
  local title = opts.title or "jj-waltz.nvim"
  if opts.enabled == false then
    return
  end
  vim.notify(message, level or vim.log.levels.INFO, { title = title })
end

function M.command_string(command)
  return table.concat(command, " ")
end

return M
