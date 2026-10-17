# jj-waltz.nvim

`jj-waltz.nvim` is a Neovim wrapper around the [`jw`](https://github.com/EzraCerpac/jj-waltz) CLI from `jj-waltz`.
It gives you workspace switching, quick actions, and a built-in picker without requiring Telescope, plenary, or other runtime dependencies.

## Requirements

- Neovim `>= 0.10`
- A `jw` binary with:
  - `links` subcommands
  - `switch --print-path`

In practice, use `jj-waltz` `>= 0.1.5` or a build from the current `jj-waltz` repo.

## Features

- `:JwPick` workspace picker using `vim.ui.select`
- `:JwSwitch {name}` with a tab per workspace via `jw switch --print-path`
- `:JwCurrent`, `:JwRoot`, `:JwPath {name}`
- `:JwRemove [name]`, `:JwRemoveKeepDir [name]`, `:JwPrune`
- `:JwLinksApply`, `:JwLinksRepair`
- optional workspace creation flow with `--at` and `--bookmark`
- link conflict follow-up prompts

## Installation

### lazy.nvim

```lua
{
  "EzraCerpac/jj-waltz.nvim",
  main = "jj-waltz",
  cmd = {
    "JwPick",
    "JwSwitch",
    "JwCurrent",
    "JwRoot",
    "JwPath",
    "JwRemove",
    "JwRemoveKeepDir",
    "JwPrune",
    "JwLinksApply",
    "JwLinksRepair",
  },
  opts = {
    jw_cmd = "~/.local/bin/jw",
  },
  keys = {
    { "<leader>jw", "<cmd>JwPick<cr>", desc = "jj-waltz picker" },
  },
}
```

### Local Development

```lua
{
  dir = vim.fn.expand("~/Projects/jj-waltz.nvim"),
  name = "jj-waltz.nvim",
  main = "jj-waltz",
  cmd = {
    "JwPick",
    "JwSwitch",
    "JwCurrent",
    "JwRoot",
    "JwPath",
    "JwRemove",
    "JwRemoveKeepDir",
    "JwPrune",
    "JwLinksApply",
    "JwLinksRepair",
  },
  opts = {
    jw_cmd = vim.fn.expand("~/.local/bin/jw"),
  },
  keys = {
    { "<leader>jw", "<cmd>JwPick<cr>", desc = "jj-waltz picker" },
  },
}
```

## Configuration

```lua
require("jj-waltz").setup({
  jw_cmd = "jw",
  picker = "vim_ui_select",
  switch_behavior = "retarget",
  open_strategy = "cwd",
  notify = true,
  keymaps = false,
})
```

## Behavior Notes

- The plugin shells out to `jw`. It does not call Rust internals directly.
- Switching adopts the starting tab and keeps one tab per visited workspace root. Returning restores that tab's windows, splits, active window, cursor positions, and views. First visits start with one window, opening the current clean file at the same relative path when it exists (with the cursor clamped to fit).
- Modified buffers stay in their original workspace tab. Missing counterparts, unnamed buffers, special buffers, and files outside the source workspace start an empty destination tab. Switching never forces a write, reload, rename, or buffer deletion.
- New workspace tabs use `:tcd` with the destination from `jw` (including its subdirectory fallback). Existing tabs retain their cwd scopes, including `:lcd`; the global cwd and unrelated tabs are untouched. A restored tab's cwd can therefore differ from the CLI's destination. CLI actions use the active window's effective cwd.
- Tabs are associated by resolved root path, not workspace name or token. Renames at the same path reuse a tab; moved workspaces get a new tab. Removed workspaces leave their tabs and buffers available for recovery; a failed switch keeps the current tab. Reusing a root path reuses its tab. Closing a tab forgets that context; switching back creates a fresh one. Context lasts for the current Neovim session.
- If a tab's active cwd no longer resolves to its associated workspace (for example after a manual `:tcd` into another workspace), it is left intact and detached from that association. Switching back creates a fresh tab with the correct workspace cwd.
- Link conflicts surface as actionable Neovim prompts that can run `:JwLinksRepair` or `:JwLinksApply`.

## Commands

- `:JwPick`
- `:JwSwitch {name}`
- `:JwCurrent`
- `:JwRoot`
- `:JwPath {name}`
- `:JwRemove [name]`
- `:JwRemoveKeepDir [name]`
- `:JwPrune`
- `:JwLinksApply`
- `:JwLinksRepair`

## Testing

```bash
nvim --headless -u tests/minimal_init.lua -c "lua require('tests.run').run()" -c "qa!"
```

## License

MIT
