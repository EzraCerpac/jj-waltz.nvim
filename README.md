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
- `:JwSwitch {name}` with editor retargeting via `jw switch --print-path`
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
- Switching is editor-aware: it uses `jw switch --print-path`, changes Neovim into the destination directory, and reopens the current buffer in the target workspace when the matching file exists.
- If the current buffer has unsaved changes, the plugin changes cwd but skips reopening that buffer.
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
