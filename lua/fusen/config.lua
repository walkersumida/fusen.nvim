local M = {}

M.defaults = {
  save_file = vim.fn.expand("$HOME") .. "/fusen_marks.json",

  mark = {
    icon = "📝",
    hl_group = "FusenMark",
  },

  keymaps = {
    add_mark = "mi",
    clear_mark = "mc",
    clear_buffer = "mC",
    clear_all = "mD",
    next_mark = "mn",
    prev_mark = "mp",
    list_marks = "ml",
  },

  branch_aware = true,

  auto_save = true,

  sign_priority = 10,

  annotation_display = {
    mode = "float", -- "eol", "float", "both", "none"
    prefix = " 📝 ",

    float = {
      delay = 100,
      border = "rounded",
      max_width = 50,
      max_height = 10,
    },
  },
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
