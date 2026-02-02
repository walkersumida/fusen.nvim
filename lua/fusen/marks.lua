local M = {}
local git = require("fusen.git")

-- Generate hash from line content (trimmed)
local function get_line_hash(content)
  local trimmed = content:match("^%s*(.-)%s*$") or ""
  return vim.fn.sha256(trimmed):sub(1, 16)
end

-- extmark namespaces for each buffer
local namespaces = {}
-- Main data structure: { file_path -> { branch -> [ mark_data ] } }
local file_marks_data = {}
-- Display management: { bufnr -> { line -> extmark_id } }
local buffer_extmarks = {}
local current_branch = nil
-- Track loaded buffers to prevent duplicate loading
local loaded_buffers = {}

-- Get or create namespace for buffer
local function get_namespace(bufnr)
  if not namespaces[bufnr] then
    namespaces[bufnr] = vim.api.nvim_create_namespace("fusen_buffer_" .. bufnr)
  end
  return namespaces[bufnr]
end

-- Helper to get branch key
local function get_mark_key(file_path, branch)
  if not branch then
    return "global"
  end
  return branch
end

-- Initialize mark structure for file and branch
local function ensure_mark_structure(file_path, branch_key)
  if not file_marks_data[file_path] then
    file_marks_data[file_path] = {}
  end
  if not file_marks_data[file_path][branch_key] then
    file_marks_data[file_path][branch_key] = {}
  end
  return file_marks_data[file_path][branch_key]
end

-- Get marks for a specific file and branch
local function get_file_marks(file_path, branch_key)
  if not file_marks_data[file_path] or not file_marks_data[file_path][branch_key] then
    return {}
  end
  return file_marks_data[file_path][branch_key]
end

-- Create extmark for display
local function create_extmark(bufnr, line, mark_data)
  local ns_id = get_namespace(bufnr)
  local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, line - 1, 0, {
    strict = false,
    -- Automatically adjust position when text changes
    right_gravity = false, -- Don't move left when inserting
    -- Handle when line is deleted
    invalidate = true, -- Invalidate extmark when line is deleted
  })

  if extmark_id then
    if not buffer_extmarks[bufnr] then
      buffer_extmarks[bufnr] = {}
    end
    buffer_extmarks[bufnr][line] = extmark_id
  end

  return extmark_id
end

-- Sync extmark positions with stored data
function M.sync_extmark_positions(bufnr)
  if not buffer_extmarks[bufnr] then
    return
  end

  local ns_id = get_namespace(bufnr)
  local position_changed = false

  for stored_line, extmark_id in pairs(buffer_extmarks[bufnr]) do
    local ok, extmarks = pcall(vim.api.nvim_buf_get_extmarks, bufnr, ns_id, extmark_id, extmark_id, {})
    if ok and #extmarks > 0 then
      local current_line = extmarks[1][2] + 1 -- Convert 0-indexed to 1-indexed
      if current_line ~= stored_line then
        M.update_mark_line(bufnr, stored_line, current_line)
        -- Update content_hash for the new line
        local lines = vim.api.nvim_buf_get_lines(bufnr, current_line - 1, current_line, false)
        if lines[1] then
          local file_path = vim.api.nvim_buf_get_name(bufnr)
          local branch = current_branch or git.get_current_branch()
          local branch_key = get_mark_key(file_path, branch)
          local marks_list = get_file_marks(file_path, branch_key)
          for _, mark in ipairs(marks_list) do
            if mark.line == current_line then
              mark.content_hash = get_line_hash(lines[1])
              break
            end
          end
        end
        position_changed = true
      end
    end
  end

  -- Save to JSON file only when position changes
  if position_changed then
    local storage = require("fusen.storage")
    storage.save()
  end
end

-- Remove extmark from display
local function remove_extmark(bufnr, line)
  if not buffer_extmarks[bufnr] or not buffer_extmarks[bufnr][line] then
    return
  end

  local ns_id = get_namespace(bufnr)
  local extmark_id = buffer_extmarks[bufnr][line]
  vim.api.nvim_buf_del_extmark(bufnr, ns_id, extmark_id)
  buffer_extmarks[bufnr][line] = nil
end

-- Get current line number for extmark
local function get_extmark_line(bufnr, line)
  if not buffer_extmarks[bufnr] or not buffer_extmarks[bufnr][line] then
    return nil
  end

  local ns_id = get_namespace(bufnr)
  local extmark_id = buffer_extmarks[bufnr][line]
  local ok, extmarks = pcall(vim.api.nvim_buf_get_extmarks, bufnr, ns_id, extmark_id, extmark_id, {})

  if ok and #extmarks > 0 then
    return extmarks[1][2] + 1 -- Convert 0-indexed to 1-indexed
  end
  return nil
end

-- Update mark position in data when extmark moves
function M.update_mark_line(bufnr, old_line, new_line)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local file_path = vim.api.nvim_buf_get_name(bufnr)
  if file_path == "" then
    return
  end

  local branch = current_branch or git.get_current_branch()
  local branch_key = get_mark_key(file_path, branch)
  local marks_list = get_file_marks(file_path, branch_key)

  -- Find and update mark at old_line
  for _, mark in ipairs(marks_list) do
    if mark.line == old_line then
      mark.line = new_line
      -- Update buffer_extmarks mapping
      if buffer_extmarks[bufnr] and buffer_extmarks[bufnr][old_line] then
        buffer_extmarks[bufnr][new_line] = buffer_extmarks[bufnr][old_line]
        buffer_extmarks[bufnr][old_line] = nil
      end
      break
    end
  end
end

function M.add_mark(bufnr, line, annotation)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local file_path = vim.api.nvim_buf_get_name(bufnr)
  if file_path == "" then
    return
  end

  local branch = current_branch or git.get_current_branch()
  local branch_key = get_mark_key(file_path, branch)
  local marks_list = ensure_mark_structure(file_path, branch_key)

  -- Check if mark already exists at this line
  local existing_index = nil
  for i, mark in ipairs(marks_list) do
    if mark.line == line then
      existing_index = i
      break
    end
  end

  -- Get line content and compute hash
  local lines = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)
  local content_hash = nil
  if lines[1] then
    content_hash = get_line_hash(lines[1])
  end

  local mark_data = {
    line = line,
    annotation = annotation or "",
    created_at = os.time(),
    content_hash = content_hash,
  }

  if existing_index then
    -- Update existing mark
    marks_list[existing_index] = mark_data
    remove_extmark(bufnr, line)
  else
    -- Add new mark
    table.insert(marks_list, mark_data)
  end

  -- Create extmark for display
  create_extmark(bufnr, line, mark_data)
end

function M.remove_mark(bufnr, line)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local file_path = vim.api.nvim_buf_get_name(bufnr)
  if file_path == "" then
    return
  end

  local branch = current_branch or git.get_current_branch()
  local branch_key = get_mark_key(file_path, branch)
  local marks_list = get_file_marks(file_path, branch_key)

  -- Remove from data
  for i, mark in ipairs(marks_list) do
    if mark.line == line then
      table.remove(marks_list, i)
      break
    end
  end

  -- Clean up empty data structures
  if #marks_list == 0 then
    file_marks_data[file_path][branch_key] = nil
    if next(file_marks_data[file_path]) == nil then
      file_marks_data[file_path] = nil
    end
  end

  -- Remove extmark
  remove_extmark(bufnr, line)
end

function M.get_mark(bufnr, line)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return nil
  end

  local file_path = vim.api.nvim_buf_get_name(bufnr)
  if file_path == "" then
    return nil
  end

  local branch = current_branch or git.get_current_branch()
  local branch_key = get_mark_key(file_path, branch)
  local marks_list = get_file_marks(file_path, branch_key)

  for _, mark in ipairs(marks_list) do
    if mark.line == line then
      return mark
    end
  end

  return nil
end

function M.update_annotation(bufnr, line, annotation)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local file_path = vim.api.nvim_buf_get_name(bufnr)
  if file_path == "" then
    return
  end

  local branch = current_branch or git.get_current_branch()
  local branch_key = get_mark_key(file_path, branch)
  local marks_list = get_file_marks(file_path, branch_key)

  for _, mark in ipairs(marks_list) do
    if mark.line == line then
      mark.annotation = annotation or ""
      break
    end
  end
end

function M.get_buffer_marks(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return {}
  end

  local file_path = vim.api.nvim_buf_get_name(bufnr)
  if file_path == "" then
    return {}
  end

  local branch = current_branch or git.get_current_branch()
  local branch_key = get_mark_key(file_path, branch)
  local marks_list = get_file_marks(file_path, branch_key)

  local result = {}
  for _, mark in ipairs(marks_list) do
    table.insert(
      result,
      vim.tbl_extend("force", mark, {
        file = file_path,
        buffer = bufnr,
      })
    )
  end

  -- Sort by line number
  table.sort(result, function(a, b)
    return a.line < b.line
  end)

  return result
end

function M.get_next_mark(bufnr, current_line)
  local buffer_marks = M.get_buffer_marks(bufnr)

  for _, mark in ipairs(buffer_marks) do
    if mark.line > current_line then
      return mark
    end
  end

  return nil
end

function M.get_prev_mark(bufnr, current_line)
  local buffer_marks = M.get_buffer_marks(bufnr)

  for i = #buffer_marks, 1, -1 do
    local mark = buffer_marks[i]
    if mark.line < current_line then
      return mark
    end
  end

  return nil
end

function M.get_marks(current_branch)
  local all_marks = {}
  local branch = current_branch or git.get_current_branch()
  local branch_key = get_mark_key(nil, branch)

  for file_path, branch_data in pairs(file_marks_data) do
    if branch_data[branch_key] then
      for _, mark_data in ipairs(branch_data[branch_key]) do
        table.insert(
          all_marks,
          vim.tbl_extend("force", mark_data, {
            file = file_path,
          })
        )
      end
    end
  end

  -- Sort by file path and line number
  table.sort(all_marks, function(a, b)
    if a.file == b.file then
      return a.line < b.line
    end
    return a.file < b.file
  end)

  return all_marks
end

function M.clear_buffer_marks(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local file_path = vim.api.nvim_buf_get_name(bufnr)
  if file_path == "" then
    return
  end

  local branch = current_branch or git.get_current_branch()
  local branch_key = get_mark_key(file_path, branch)

  -- Clear from data
  if file_marks_data[file_path] and file_marks_data[file_path][branch_key] then
    file_marks_data[file_path][branch_key] = nil
    if next(file_marks_data[file_path]) == nil then
      file_marks_data[file_path] = nil
    end
  end

  -- Clear extmarks
  if buffer_extmarks[bufnr] then
    local ns_id = get_namespace(bufnr)
    for line, extmark_id in pairs(buffer_extmarks[bufnr]) do
      vim.api.nvim_buf_del_extmark(bufnr, ns_id, extmark_id)
    end
    buffer_extmarks[bufnr] = {}
  end
end

function M.clear_all_marks()
  -- Clear all data
  file_marks_data = {}

  -- Clear all extmarks
  for bufnr, line_extmarks in pairs(buffer_extmarks) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      local ns_id = get_namespace(bufnr)
      for line, extmark_id in pairs(line_extmarks) do
        vim.api.nvim_buf_del_extmark(bufnr, ns_id, extmark_id)
      end
    end
  end
  buffer_extmarks = {}
end

function M.init()
  file_marks_data = {}
  buffer_extmarks = {}
  current_branch = nil
  loaded_buffers = {}
end

-- For storage compatibility
function M.set_marks_data(data)
  -- Clear existing data
  M.clear_all_marks()
  file_marks_data = {}

  if not data then
    return
  end

  -- Store file-based data only (no extmark creation)
  file_marks_data = vim.deepcopy(data)

  -- Extmarks will be created by load_buffer_marks when buffers are loaded
end

function M.get_marks_data()
  return file_marks_data
end

-- Reset loaded state for a buffer to allow re-loading marks (e.g., after :e)
function M.reset_buffer_loaded(bufnr)
  local file_path = vim.api.nvim_buf_get_name(bufnr)
  if file_path ~= "" then
    local buffer_key = bufnr .. ":" .. file_path
    loaded_buffers[buffer_key] = nil
  end
end

-- Load marks for a specific buffer from saved data
function M.load_buffer_marks(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local file_path = vim.api.nvim_buf_get_name(bufnr)
  if file_path == "" then
    return
  end

  -- Prevent duplicate loading for the same buffer
  local buffer_key = bufnr .. ":" .. file_path
  if loaded_buffers[buffer_key] then
    return
  end
  loaded_buffers[buffer_key] = true

  -- Get branch info
  local branch = current_branch or git.get_current_branch()
  local branch_key = get_mark_key(file_path, branch)

  -- Use in-memory data
  if not file_marks_data[file_path] or not file_marks_data[file_path][branch_key] then
    return
  end

  local file_marks = file_marks_data[file_path][branch_key]

  -- Clear existing extmarks for this buffer
  if buffer_extmarks[bufnr] then
    local ns_id = get_namespace(bufnr)
    for line, extmark_id in pairs(buffer_extmarks[bufnr]) do
      vim.api.nvim_buf_del_extmark(bufnr, ns_id, extmark_id)
    end
    buffer_extmarks[bufnr] = {}
  end

  -- Get all buffer lines for hash matching
  local buffer_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  local position_changed = false

  -- Restore marks
  for _, mark_data in ipairs(file_marks) do
    local resolved_line = mark_data.line

    -- Try to find line by content_hash if available
    if mark_data.content_hash then
      local matching_lines = {}
      for i, line_content in ipairs(buffer_lines) do
        if get_line_hash(line_content) == mark_data.content_hash then
          table.insert(matching_lines, i)
        end
      end

      if #matching_lines > 0 then
        -- Find the line closest to the original line number
        local closest_line = matching_lines[1]
        local min_distance = math.abs(closest_line - mark_data.line)
        for _, line_num in ipairs(matching_lines) do
          local distance = math.abs(line_num - mark_data.line)
          if distance < min_distance then
            min_distance = distance
            closest_line = line_num
          end
        end
        resolved_line = closest_line
        if mark_data.line ~= resolved_line then
          mark_data.line = resolved_line
          position_changed = true
        end
      end
    end

    create_extmark(bufnr, resolved_line, mark_data)
  end

  -- Save to JSON file if position changed
  if position_changed then
    local storage = require("fusen.storage")
    storage.save()
  end
end

-- Clean up extmarks for closed buffers
function M.cleanup_closed_buffers()
  for bufnr, _ in pairs(buffer_extmarks) do
    if not vim.api.nvim_buf_is_valid(bufnr) then
      buffer_extmarks[bufnr] = nil
    end
  end

  -- Clean up loaded_buffers for closed buffers
  for buffer_key, _ in pairs(loaded_buffers) do
    local bufnr = tonumber(buffer_key:match("^(%d+):"))
    if bufnr and not vim.api.nvim_buf_is_valid(bufnr) then
      loaded_buffers[buffer_key] = nil
    end
  end
end

return M
