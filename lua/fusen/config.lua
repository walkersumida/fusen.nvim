local M = {}

M.defaults = {
  save_file = vim.fn.expand("$HOME") .. "/fusen_marks.json",

  mark = {
    icon = "📝",
    hl_group = "FusenMark",
  },

  keymaps = {
    add_mark = "me",
    clear_mark = "mc",
    toggle_mark = "mt",
    clear_buffer = "mC",
    clear_all = "mD",
    next_mark = "mn",
    prev_mark = "mp",
    list_marks = "ml",
    yank_line = "my",
    yank_buffer = "mY",
    yank_all = "mA",
  },

  yank = {
    -- Template for each mark. Placeholders: {path} {file} {line} {annotation}
    template = '- @{path}:L{line} - "{annotation}"',
    -- Used instead when the mark has no annotation
    template_no_annotation = "- @{path}:L{line}",
  },

  toggle_mark = {
    skip_confirm = false, -- Skip confirmation when removing mark via toggle
  },

  telescope = {
    keymaps = {
      delete_mark_insert = "<C-d>",
      delete_mark_normal = "<C-d>",
    },
  },

  sign_priority = 10,

  annotation_display = {
    mode = "float", -- "eol", "float", "both", "none"
    spacing = 2, -- Number of spaces to add before annotation in eol mode

    float = {
      delay = 100,
      border = "rounded",
      max_width = 50,
      max_height = 10,
    },
  },

  exclude_filetypes = {},

  enabled = true,
}

M.options = {}

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})

  -- Set up highlight for marks
  vim.api.nvim_set_hl(0, M.options.mark.hl_group, { link = "Special", default = true })

  return M.options
end

function M.get()
  return M.options
end

return M
