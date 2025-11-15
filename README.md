# 📝 fusen.nvim

A sticky notes plugin for Neovim with git branch awareness. Place sticky notes (fusen - 付箋 in Japanese) in your code and keep them organized across different git branches.

![Neovim](https://img.shields.io/badge/Neovim-0.7+-green.svg)
![Lua](https://img.shields.io/badge/Lua-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)
[![Tests](https://github.com/walkersumida/fusen.nvim/actions/workflows/test.yml/badge.svg)](https://github.com/walkersumida/fusen.nvim/actions/workflows/test.yml)

https://github.com/user-attachments/assets/4ebcb70b-0be8-4668-8a65-2eb5c950aec4

<table>
  <tr>
    <th>Adding/Editing an annotation</th>
  </tr>
  <tr>
    <td>
      <img src="https://github.com/user-attachments/assets/8a2d1746-8b34-468b-8e44-6d8797bb7b96" />
    </td>
  </tr>
  <tr>
    <th>Viewing annotation</th>
  </tr>
  <tr>
    <td>
      <img src="https://github.com/user-attachments/assets/43b4f48a-82ce-4af7-8408-a841ed217b82" />
    </td>
  </tr>
  <tr>
    <th>Listing marks in Telescope</th>
  </tr>
  <tr>
    <td>
      <img src="https://github.com/user-attachments/assets/4d91a644-4261-4e88-ae15-1bc4836f5e03" />
    </td>
  </tr>
</table>

## ✨ Features

- 📝 **Simple sticky notes** - Clean and minimalist sticky note system
- 🌳 **Git branch awareness** - Sticky notes are stored per git branch
- 💾 **Persistent storage** - Your sticky notes are saved between sessions
- 📝 **Annotations** - Add descriptive text to your sticky notes
- 🎈 **Float window display** - Show annotations in floating windows on cursor hover
- 🔍 **Telescope integration** - Search and navigate through all your sticky notes
- ⚡ **Fast navigation** - Jump between sticky notes quickly
- 📋 **Quickfix list support** - View all sticky notes in a quickfix list

## 📦 Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "walkersumida/fusen.nvim",
  version = "*",
  event = "VimEnter",
  opts = {},
}
```

For custom save file location:
```lua
{
  "walkersumida/fusen.nvim",
  version = "*",
  event = "VimEnter",
  opts = {
    save_file = vim.fn.expand("$HOME") .. "/my_fusen_marks.json",
  }
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "walkersumida/fusen.nvim",
  config = function()
    require("fusen").setup()  -- Add options here if needed
  end
}
```

> **Note:** Configuration examples below use lazy.nvim's `opts` syntax. For packer.nvim, pass the same options to `setup()`.

### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'walkersumida/fusen.nvim'
```

Then add to your init.lua:
```lua
require("fusen").setup()  -- Add options here if needed
```

> **Note:** Configuration examples below use lazy.nvim's `opts` syntax. For vim-plug, pass the same options to `setup()`.

## ⚙️ Configuration

### Default Configuration

```lua
-- Using lazy.nvim
{
  "walkersumida/fusen.nvim",
  opts = {
    -- Storage location
    save_file = vim.fn.expand("$HOME") .. "/fusen_marks.json",

    -- Mark appearance
    mark = {
      icon = "📝",
      hl_group = "FusenMark",
    },

    -- Key mappings
    keymaps = {
      add_mark = "me",        -- Add/edit sticky note
      clear_mark = "mc",      -- Clear mark at current line
      clear_buffer = "mC",    -- Clear all marks in buffer
      clear_all = "mD",       -- Clear ALL marks (deletes entire JSON content)
      next_mark = "mn",       -- Jump to next mark
      prev_mark = "mp",       -- Jump to previous mark
      list_marks = "ml",      -- Show marks in quickfix
    },

    -- Telescope integration settings
    telescope = {
      keymaps = {
        delete_mark_insert = "<C-d>",  -- Delete mark in insert mode
        delete_mark_normal = "<C-d>",  -- Delete mark in normal mode
      },
    },

    -- Sign column priority
    sign_priority = 10,

    -- Annotation display settings
    annotation_display = {
      mode = "float", -- "eol", "float", "both", "none"
      spacing = 2,    -- Number of spaces before annotation in eol mode

      -- Float window settings
      float = {
        delay = 100,
        border = "rounded",
        max_width = 50,
        max_height = 10,
      },
    },

    -- Exclude specific filetypes from keymaps
    exclude_filetypes = {
      -- "neo-tree",     -- Example: neo-tree
      -- "NvimTree",     -- Example: nvim-tree
      -- "nerdtree",     -- Example: NERDTree
    },

    -- Plugin enabled state
    enabled = true,
  }
}
```

### Annotation Display Modes

The `annotation_display.mode` option controls how annotations are displayed:

- **`"eol"`**: Shows annotations at the end of the line (traditional mode)
- **`"float"`**: Shows annotations in a floating window when cursor hovers over a marked line
- **`"both"`**: Shows both end-of-line text and floating window
- **`"none"`**: Hides annotations (marks only)

#### Float Window Settings

```lua
-- Using lazy.nvim
{
  "walkersumida/fusen.nvim",
  opts = {
    annotation_display = {
      mode = "float",
      float = {
        delay = 300,         -- Show after 300ms (default: 100ms)
        border = "single",   -- Border style: "single", "double", "rounded", etc.
        max_width = 60,      -- Maximum width (default: 50)
        max_height = 15,     -- Maximum height (default: 10)
      }
    }
  }
}
```

- **`delay`**: Time in milliseconds to wait after cursor stops before showing the float window
- **`border`**: Border style for the float window
- **`max_width`** / **`max_height`**: Maximum dimensions for the float window

## 🎮 Usage

### Key Mappings

All default mappings start with `m` prefix for consistency:

| Key | Description |
|-----|-------------|
| `me` | Add or edit sticky note with annotation |
| `mc` | Clear sticky note at current line |
| `mC` | Clear all sticky notes in current buffer |
| `mD` | Clear ALL sticky notes (deletes entire JSON content) |
| `mn` | Jump to next sticky note |
| `mp` | Jump to previous sticky note |
| `ml` | List all sticky notes in quickfix |

### Commands

| Command | Description |
|---------|-------------|
| `:FusenAddMark` | Add or edit sticky note with annotation |
| `:FusenClearMark` | Clear sticky note at current line |
| `:FusenClearBuffer` | Clear all marks in current buffer |
| `:FusenClearAll` | Clear ALL marks (deletes entire JSON content) |
| `:FusenNext` | Jump to next mark |
| `:FusenPrev` | Jump to previous mark |
| `:FusenList` | Show all marks in quickfix list |
| `:FusenRefresh` | Refresh all marks display |
| `:FusenSave` | Manually save marks |
| `:FusenLoad` | Manually load marks |
| `:FusenInfo` | Show info about mark at current line |
| `:FusenBranch` | Show current git branch info |
| `:FusenOpenSaveFile` | Open save file for debugging/editing |
| `:FusenEnable` | Enable Fusen plugin (show marks and annotations) |
| `:FusenDisable` | Disable Fusen plugin (hide all marks and annotations) |
| `:FusenToggle` | Toggle Fusen on/off |

### Telescope Integration

If you have [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) installed:

```lua
-- Search through all sticky notes
:Telescope fusen marks

-- Set up a keybinding (example)
vim.keymap.set("n", "<leader>fm", ":Telescope fusen marks<CR>", { desc = "Find fusen marks" })

-- In Telescope window:
-- <CR> - Jump to mark
-- <C-d> - Delete mark (customizable, see configuration)

-- Custom key mappings for Telescope (using lazy.nvim)
{
  "walkersumida/fusen.nvim",
  opts = {
    telescope = {
      keymaps = {
        delete_mark_insert = "<C-x>",  -- Custom key for insert mode
        delete_mark_normal = "dd",     -- Custom key for normal mode
      },
    },
  }
}
```

## 🌳 Git Branch Awareness

One of the unique features of fusen.nvim is its git branch awareness. When you switch git branches, your sticky notes automatically switch too!

```bash
# On main branch
git checkout main
# Your main branch sticky notes are loaded

# Switch to feature branch
git checkout feature/new-feature
# Your feature branch sticky notes are loaded

# Sticky notes are stored separately for each branch
```

This is especially useful when:
- Working on multiple features simultaneously
- Reviewing different versions of code
- Keeping TODO items branch-specific
- Maintaining separate documentation notes per branch

## 🎨 Customization

### Float Window Display

Configure how annotations appear in floating windows:

```lua
-- Using lazy.nvim
{
  "walkersumida/fusen.nvim",
  opts = {
    annotation_display = {
      mode = "float",  -- Use floating windows
      float = {
        delay = 300,         -- Show after 300ms
        border = "single",   -- Border style
        max_width = 60,      -- Maximum width
        max_height = 15,     -- Maximum height
      }
    }
  }
}
```

### Custom Highlighting

You can customize the appearance of marks by changing the highlight group:

```lua
-- Using lazy.nvim
{
  "walkersumida/fusen.nvim",
  opts = {
    mark = {
      icon = "📝",
      hl_group = "MyCustomHighlight",  -- Custom highlight group
    },
  },
  config = function(_, opts)
    require("fusen").setup(opts)
    -- Define your custom highlight group
    vim.api.nvim_set_hl(0, "MyCustomHighlight", {
      fg = "#ff6b6b",      -- Red foreground
      bg = "#1e1e1e",      -- Dark background
      bold = true,         -- Bold text
    })
  end,
}
```

The `hl_group` setting controls the color and style of:
- Mark icons in the sign column
- Annotation text display
- Mark icons in Telescope search results

By default, it uses the "Special" highlight group which typically appears in a distinct color in most colorschemes.

### Custom Key Mappings

```lua
-- Set your own mappings
vim.keymap.set("n", "<leader>m", require("fusen").add_mark)
vim.keymap.set("n", "<leader>mc", require("fusen").clear_mark)
-- etc...
```

## ⭐ Show your support

Give a ⭐️ if this project helped you! Thank you!
