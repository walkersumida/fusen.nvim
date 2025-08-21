local M = {}

local namespace = vim.api.nvim_create_namespace("fusen")
local sign_group = "FusenSigns"
local float_win = nil
local float_buf = nil
local float_timer = nil

function M.setup_signs()
  local config = require("fusen.config").get()
  local mark_config = config.mark

  vim.fn.sign_define("FusenSign", {
    text = mark_config.icon,
    texthl = mark_config.hl_group,
    numhl = mark_config.hl_group,
  })
end

local function close_float_window()
  if float_timer then
    vim.fn.timer_stop(float_timer)
    float_timer = nil
  end

  if float_win and vim.api.nvim_win_is_valid(float_win) then
    vim.api.nvim_win_close(float_win, true)
  end

  if float_buf and vim.api.nvim_buf_is_valid(float_buf) then
    vim.api.nvim_buf_delete(float_buf, { force = true })
  end

  float_win = nil
  float_buf = nil
end

local function show_float_window(annotation, opts)
  close_float_window()

  if not annotation or annotation == "" then
    return
  end

  local config = require("fusen.config").get()
  local float_config = config.annotation_display.float or {}

  -- Create buffer for the floating window
  float_buf = vim.api.nvim_create_buf(false, true)

  -- Format the annotation text
  local prefix = config.annotation_display.prefix or ""
  local full_text = prefix .. annotation
  local lines = vim.split(full_text, "\n", { plain = true })

  vim.api.nvim_buf_set_lines(float_buf, 0, -1, false, lines)

  --  Size calculation
  local max_width = float_config.max_width or 50
  local min_width = float_config.min_width or 1
  local max_height = float_config.max_height or 10
  local min_height = float_config.min_height or 1

  -- Calculate the longest display width among all lines
  local longest = 1
  for _, line in ipairs(lines) do
    local w = vim.fn.strdisplaywidth(line)
    if w > longest then
      longest = w
    end
  end

  -- Width is based on longest line, but clamped to [min_width, max_width]
  local width = math.min(max_width, math.max(min_width, longest))

  -- Adjust effective width if 'showbreak' is set (prefix shown for wrapped lines)
  local showbreak_w = vim.fn.strdisplaywidth(vim.o.showbreak or "")
  local eff_width = math.max(1, width - showbreak_w)

  -- Calculate wrapped height (each long line may occupy multiple rows)
  local function calc_wrapped_height(lines_, eff_w)
    local total = 0
    for _, line in ipairs(lines_) do
      local w = vim.fn.strdisplaywidth(line)
      if w == 0 then
        total = total + 1
      else
        total = total + math.max(1, math.ceil(w / eff_w))
      end
    end
    return total
  end

  local height = calc_wrapped_height(lines, eff_width)
  height = math.min(max_height, math.max(min_height, height))

  -- Create floating window
  float_win = vim.api.nvim_open_win(float_buf, false, {
    relative = "cursor",
    row = 1,
    col = 0,
    width = width,
    height = height,
    style = "minimal",
    border = float_config.border or "rounded",
  })

  -- Buffer / Window options
  vim.api.nvim_buf_set_option(float_buf, "modifiable", false)
  vim.api.nvim_buf_set_option(float_buf, "buftype", "nofile")

  -- Enable wrapping so text actually folds to the calculated width
  vim.api.nvim_win_set_option(float_win, "wrap", true)
  vim.api.nvim_win_set_option(float_win, "linebreak", true) -- do not break mid-word
  if float_config.breakindent then
    vim.api.nvim_win_set_option(float_win, "breakindent", true)
  end

  -- Highlight groups
  vim.api.nvim_win_set_option(float_win, "winhl", "Normal:NormalFloat,FloatBorder:FloatBorder")
end

function M.refresh_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local file_path = vim.api.nvim_buf_get_name(bufnr)
  if file_path == "" then
    return
  end

  local marks = require("fusen.marks")

  -- Sync extmark positions with data before refreshing
  marks.sync_extmark_positions(bufnr)

  M.clear_buffer(bufnr)

  local file_marks = marks.get_buffer_marks(bufnr)
  local config = require("fusen.config").get()

  for _, mark in ipairs(file_marks) do
    local sign_id = mark.line * 1000 + (mark.created_at or 0) % 1000

    vim.fn.sign_place(sign_id, sign_group, "FusenSign", bufnr, {
      lnum = mark.line,
      priority = config.sign_priority,
    })

    -- Handle virtual text based on mode
    if mark.annotation and mark.annotation ~= "" then
      local mode = config.annotation_display.mode

      if mode == "eol" or mode == "both" then
        local virt_text = {
          { config.annotation_display.prefix .. mark.annotation, config.mark.hl_group },
        }

        pcall(vim.api.nvim_buf_set_extmark, bufnr, namespace, mark.line - 1, 0, {
          virt_text = virt_text,
          virt_text_pos = "eol",
          hl_mode = "combine",
          priority = config.sign_priority,
        })
      end
    end
  end
end

function M.clear_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  vim.fn.sign_unplace(sign_group, { buffer = bufnr })
  vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
end

function M.show_mark_info(bufnr, line)
  local marks = require("fusen.marks")
  local mark = marks.get_mark(bufnr, line)

  if not mark then
    vim.notify("No mark at current line", vim.log.levels.INFO)
    return
  end

  local config = require("fusen.config").get()

  local info = string.format(
    "%s Mark\nLine: %d\nAnnotation: %s\nCreated: %s",
    config.mark.icon,
    mark.line,
    mark.annotation ~= "" and mark.annotation or "(none)",
    os.date("%Y-%m-%d %H:%M:%S", mark.created_at)
  )

  vim.notify(info, vim.log.levels.INFO, { title = "Fusen Mark Info" })
end

function M.create_quickfix_list()
  local marks = require("fusen.marks")
  local all_marks = marks.get_marks()
  local config = require("fusen.config").get()

  if #all_marks == 0 then
    vim.notify("No marks found", vim.log.levels.INFO)
    return
  end

  local qf_items = {}

  for _, mark in ipairs(all_marks) do
    local text = ""

    if mark.annotation ~= "" then
      text = mark.annotation
    end

    if text == "" then
      text = "Mark at line " .. mark.line
    end

    table.insert(qf_items, {
      filename = mark.file,
      lnum = mark.line,
      col = 1,
      text = text,
      type = "I",
    })
  end

  table.sort(qf_items, function(a, b)
    if a.filename == b.filename then
      return a.lnum < b.lnum
    end
    return a.filename < b.filename
  end)

  vim.fn.setqflist(qf_items, "r")
  vim.fn.setqflist({}, "a", { title = "Fusen Marks" })
  vim.cmd("copen")
end

function M.input_annotation(bufnr, line, callback)
  local marks = require("fusen.marks")
  local mark = marks.get_mark(bufnr, line)

  local current_annotation = mark and mark.annotation or ""

  vim.ui.input({
    prompt = "Enter annotation: ",
    default = current_annotation,
  }, function(input)
    if input == nil then
      return
    end

    if callback then
      callback(input)
    end
  end)
end

function M.refresh_all_buffers()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      M.refresh_buffer(bufnr)
    end
  end
end

function M.check_cursor_float()
  local config = require("fusen.config").get()
  local mode = config.annotation_display.mode

  if mode ~= "float" and mode ~= "both" then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local file_path = vim.api.nvim_buf_get_name(bufnr)

  if file_path == "" then
    close_float_window()
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]

  local marks = require("fusen.marks")
  local mark = marks.get_mark(bufnr, line) -- Now uses bufnr

  if mark and mark.annotation and mark.annotation ~= "" then
    show_float_window(mark.annotation)
  else
    close_float_window()
  end
end

function M.setup_autocmds()
  local group = vim.api.nvim_create_augroup("FusenUI", { clear = true })

  vim.api.nvim_create_autocmd({ "BufRead", "BufEnter" }, {
    group = group,
    callback = function(args)
      -- Load marks for this buffer if not already loaded
      local marks = require("fusen.marks")
      marks.load_buffer_marks(args.buf)
      M.refresh_buffer(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = group,
    callback = vim.schedule_wrap(function(args)
      M.refresh_buffer(args.buf)
    end),
  })

  -- Float window autocmds
  local config = require("fusen.config").get()
  local mode = config.annotation_display.mode
  if mode == "float" or mode == "both" then
    local delay = config.annotation_display.float.delay or 500

    vim.api.nvim_create_autocmd("CursorHold", {
      group = group,
      callback = function()
        if float_timer then
          vim.fn.timer_stop(float_timer)
        end
        float_timer = vim.fn.timer_start(delay, function()
          vim.schedule(M.check_cursor_float)
        end)
      end,
    })

    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "BufLeave", "WinLeave" }, {
      group = group,
      callback = function()
        close_float_window()
      end,
    })
  end
end

return M
