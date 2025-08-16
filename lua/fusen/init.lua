local M = {}

local config = require("fusen.config")
local marks = require("fusen.marks")
local ui = require("fusen.ui")
local storage = require("fusen.storage")
local git = require("fusen.git")

local initialized = false

-- Helper function for common buffer validation
local function get_current_buffer_info()
  local bufnr = vim.api.nvim_get_current_buf()
  local file_path = vim.api.nvim_buf_get_name(bufnr)
  local line = vim.api.nvim_win_get_cursor(0)[1]

  if file_path == "" then
    return nil, nil, nil, "Cannot operate on unnamed buffer"
  end

  return bufnr, file_path, line, nil
end

-- Helper function for confirmation with float window + immediate key input
local function confirm_action(message)
  local ok, result = pcall(function()
    local width = math.min(60, #message + 4)
    local height = 3

    -- Get cursor position and window dimensions
    local cursor = vim.api.nvim_win_get_cursor(0)
    local win_height = vim.api.nvim_win_get_height(0)
    local win_width = vim.api.nvim_win_get_width(0)

    -- Calculate position relative to cursor
    local row = 1 -- 1 line below cursor
    local col = 0 -- Same column as cursor

    -- Adjust if window would go off screen
    -- Calculate available space below cursor in window
    local cursor_row_in_window = cursor[1] - vim.fn.line('w0') + 1
    if height + 2 > win_height - cursor_row_in_window then
      row = -height - 1 -- Show above cursor instead
    end

    if cursor[2] + width > win_width then
      col = win_width - width - cursor[2] -- Shift left to fit
    end

    -- Create float window
    local buf = vim.api.nvim_create_buf(false, true)

    local win = vim.api.nvim_open_win(buf, true, {
      relative = "cursor",
      width = width,
      height = height,
      row = row,
      col = col,
      style = "minimal",
      border = "rounded",
    })

    -- Set content
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      "",
      " " .. message,
      "",
    })

    -- Make buffer non-modifiable
    vim.bo[buf].modifiable = false

    -- Force redraw to ensure window is visible
    vim.cmd("redraw")

    -- Wait for key input
    local key = vim.fn.getchar()
    local input = vim.fn.nr2char(key)

    -- Close window
    vim.api.nvim_win_close(win, true)

    -- Return true for 'y' or 'Y'
    return input == "y" or input == "Y"
  end)

  if not ok then
    vim.notify("Error in confirmation dialog: " .. tostring(result), vim.log.levels.ERROR)
    return false
  end

  return result
end

function M.setup(opts)
  if initialized then
    return
  end

  config.setup(opts)

  ui.setup_signs()

  storage.load()

  ui.setup_autocmds()
  storage.setup_autocmds()
  git.setup_autocmds()

  -- Setup cleanup for closed buffers (but avoid during shutdown)
  local group = vim.api.nvim_create_augroup("FusenCleanup", { clear = true })
  local shutting_down = false

  -- Track shutdown state
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      shutting_down = true
    end,
  })

  vim.api.nvim_create_autocmd("BufDelete", {
    group = group,
    callback = function()
      -- Don't cleanup during shutdown to preserve data
      if not shutting_down then
        vim.schedule(function()
          marks.cleanup_closed_buffers()
        end)
      end
    end,
  })

  M.setup_keymaps()
  M.setup_commands()

  initialized = true
end

function M.add_mark()
  local bufnr, file_path, line, err = get_current_buffer_info()
  if err then
    vim.notify(err, vim.log.levels.WARN)
    return
  end

  local mark = marks.get_mark(bufnr, line)
  local action = mark and "Updated" or "Added"

  ui.input_annotation(bufnr, line, function(annotation)
    if mark then
      marks.update_annotation(bufnr, line, annotation)
    else
      marks.add_mark(bufnr, line, annotation)
    end
    ui.refresh_buffer(bufnr)
    storage.save_immediate()
    vim.notify(action .. " mark", vim.log.levels.INFO)
  end)
end

function M.clear_mark()
  local bufnr, file_path, line, err = get_current_buffer_info()
  if err then
    vim.notify(err, vim.log.levels.WARN)
    return
  end

  local mark = marks.get_mark(bufnr, line)
  if not mark then
    vim.notify("No mark at current line", vim.log.levels.INFO)
    return
  end

  local confirmed = confirm_action(string.format("Delete mark at line %d? (y/n)", line))
  if confirmed then
    marks.remove_mark(bufnr, line)
    ui.refresh_buffer(bufnr)
    storage.save_immediate()
    vim.notify("Mark removed", vim.log.levels.INFO)
  end
end

function M.clear_buffer()
  local bufnr, file_path, line, err = get_current_buffer_info()
  if err then
    return
  end

  local confirmed = confirm_action("Clear all marks in buffer? (y/n)")
  if confirmed then
    marks.clear_buffer_marks(bufnr)
    ui.refresh_buffer(bufnr)
    storage.save_immediate()
    vim.notify("Buffer marks cleared", vim.log.levels.INFO)
  end
end

function M.clear_all()
  local confirmed = confirm_action("Clear ALL marks in JSON file? This will delete all bookmarks! (y/n)")
  if confirmed then
    marks.clear_all_marks()
    ui.refresh_all_buffers()
    storage.save_immediate()
    vim.notify("All marks cleared", vim.log.levels.INFO)
  end
end

function M.next_mark()
  local bufnr, file_path, current_line, err = get_current_buffer_info()
  if err then
    return
  end

  local next = marks.get_next_mark(bufnr, current_line)
  if next then
    vim.api.nvim_win_set_cursor(0, { next.line, 0 })
  end
end

function M.prev_mark()
  local bufnr, file_path, current_line, err = get_current_buffer_info()
  if err then
    return
  end

  local prev = marks.get_prev_mark(bufnr, current_line)
  if prev then
    vim.api.nvim_win_set_cursor(0, { prev.line, 0 })
  end
end

function M.list_marks()
  ui.create_quickfix_list()
end

function M.refresh_marks()
  ui.refresh_all_buffers()
end

function M.setup_keymaps()
  local opts = { noremap = true, silent = true }
  local keymaps = config.get().keymaps

  vim.keymap.set("n", keymaps.add_mark, function()
    M.add_mark()
  end, opts)
  vim.keymap.set("n", keymaps.clear_mark, function()
    M.clear_mark()
  end, opts)
  vim.keymap.set("n", keymaps.clear_buffer, function()
    M.clear_buffer()
  end, opts)
  vim.keymap.set("n", keymaps.clear_all, function()
    M.clear_all()
  end, opts)
  vim.keymap.set("n", keymaps.next_mark, function()
    M.next_mark()
  end, opts)
  vim.keymap.set("n", keymaps.prev_mark, function()
    M.prev_mark()
  end, opts)
  vim.keymap.set("n", keymaps.list_marks, function()
    M.list_marks()
  end, opts)
end

function M.setup_commands()
  vim.api.nvim_create_user_command("FusenAddMark", function()
    M.add_mark()
  end, {})

  vim.api.nvim_create_user_command("FusenClearMark", function()
    M.clear_mark()
  end, {})

  vim.api.nvim_create_user_command("FusenClearBuffer", function()
    M.clear_buffer()
  end, {})

  vim.api.nvim_create_user_command("FusenClearAll", function()
    M.clear_all()
  end, {})

  vim.api.nvim_create_user_command("FusenNext", function()
    M.next_mark()
  end, {})

  vim.api.nvim_create_user_command("FusenPrev", function()
    M.prev_mark()
  end, {})

  vim.api.nvim_create_user_command("FusenList", function()
    M.list_marks()
  end, {})

  vim.api.nvim_create_user_command("FusenRefresh", function()
    M.refresh_marks()
  end, {})

  vim.api.nvim_create_user_command("FusenSave", function()
    local result = storage.force_save()
    if result then
      vim.notify("Marks saved successfully", vim.log.levels.INFO)
    else
      vim.notify("Failed to save marks", vim.log.levels.ERROR)
    end
  end, {})

  vim.api.nvim_create_user_command("FusenLoad", function()
    storage.load()
    ui.refresh_all_buffers()
    vim.notify("Marks loaded", vim.log.levels.INFO)
  end, {})

  vim.api.nvim_create_user_command("FusenInfo", function()
    local bufnr, file_path, line, err = get_current_buffer_info()
    if not err then
      ui.show_mark_info(bufnr, line)
    end
  end, {})

  vim.api.nvim_create_user_command("FusenBranch", function()
    local branch, git_root = git.get_branch_info()
    if branch then
      vim.notify(string.format("Current branch: %s\nGit root: %s", branch, git_root), vim.log.levels.INFO)
    else
      vim.notify("Not in a git repository", vim.log.levels.INFO)
    end
  end, {})
end

return M
