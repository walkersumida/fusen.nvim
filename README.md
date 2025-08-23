# 📝 fusen.nvim

A sticky note bookmarks plugin for Neovim with git branch awareness. Place sticky notes (fusen - 付箋 in Japanese) in your code and keep them organized across different git branches.

![Neovim](https://img.shields.io/badge/Neovim-0.7+-green.svg)
![Lua](https://img.shields.io/badge/Lua-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

<table>
  <tr>
    <th>Adding/Editing an annotation</th>
  </tr>
  <tr>
    <td>
      <img src="https://github.com/user-attachments/assets/038bbff6-643a-4e87-aa28-73735a7de0e4" />
    </td>
  </tr>
  <tr>
    <th>Viewing annotation on hover</th>
  </tr>
  <tr>
    <td>
      <img src="https://github.com/user-attachments/assets/92c27b03-4ea0-426c-bf2c-ba8cbabbad83" />
    </td>
  </tr>
</table>

## ✨ Features

- 📝 **Simple sticky notes** - Clean and minimalist bookmark system
- 🌳 **Git branch awareness** - Bookmarks are stored per git branch
- 💾 **Persistent storage** - Your bookmarks are saved between sessions
- 📝 **Annotations** - Add descriptive text to your bookmarks
- 🎈 **Float window display** - Show annotations in floating windows on cursor hover
- 🔍 **Telescope integration** - Search and navigate through all your bookmarks
- ⚡ **Fast navigation** - Jump between bookmarks quickly
- 📋 **Quickfix list support** - View all bookmarks in a quickfix list

## 📦 Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "walkersumida/fusen.nvim",
  event = "VimEnter",
  config = function()
    require("fusen").setup()
  end
}
```

For custom save file location:
```lua
{
  "walkersumida/fusen.nvim",
  event = "VimEnter",
  config = function()
    require("fusen").setup({
      save_file = vim.fn.expand("$HOME") .. "/my_fusen_marks.json",
    })
  end
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "walkersumida/fusen.nvim",
  config = function()
    require("fusen").setup()
  end
}
```

### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'walkersumida/fusen.nvim'
```

Then add to your init.lua:
```lua
require("fusen").setup()
```

## ⚙️ Configuration

### Default Configuration

```lua
require("fusen").setup({
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
  }
  
  -- Sign column priority
  sign_priority = 10,
  
  -- Annotation display settings
  annotation_display = {
    mode = "float", -- "eol", "float", "both", "none"
    
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
})
```

### Annotation Display Modes

The `annotation_display.mode` option controls how annotations are displayed:

- **`"eol"`**: Shows annotations at the end of the line (traditional mode)
- **`"float"`**: Shows annotations in a floating window when cursor hovers over a marked line
- **`"both"`**: Shows both end-of-line text and floating window
- **`"none"`**: Hides annotations (marks only)

#### Float Window Settings

```lua
require("fusen").setup({
  annotation_display = {
    mode = "float",
    float = {
      delay = 300,         -- Show after 300ms (default: 100ms)
      border = "single",   -- Border style: "single", "double", "rounded", etc.
      max_width = 60,      -- Maximum width (default: 50)
      max_height = 15,     -- Maximum height (default: 10)
    }
  }
})
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

### Telescope Integration

If you have [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) installed:

```lua
-- Search through all sticky notes
:Telescope fusen marks

-- Set up a keybinding (example)
vim.keymap.set("n", "<leader>fm", ":Telescope fusen marks<CR>", { desc = "Find fusen marks" })

-- In Telescope window:
-- <CR> - Jump to mark
-- <C-d> - Delete mark
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
require("fusen").setup({
  annotation_display = {
    mode = "float",  -- Use floating windows
    float = {
      delay = 300,         -- Show after 300ms
      border = "single",   -- Border style
      max_width = 60,      -- Maximum width
      max_height = 15,     -- Maximum height
    }
  }
})
```

### Custom Highlighting

You can customize the appearance of marks by changing the highlight group:

```lua
require("fusen").setup({
  mark = {
    icon = "📝",
    hl_group = "MyCustomHighlight",  -- Custom highlight group
  },
})

-- Define your custom highlight group
vim.api.nvim_set_hl(0, "MyCustomHighlight", {
  fg = "#ff6b6b",      -- Red foreground
  bg = "#1e1e1e",      -- Dark background
  bold = true,         -- Bold text
})
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

Give a ⭐️ if this project helped you!
