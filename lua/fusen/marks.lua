local M = {}
local git = require("fusen.git")

-- extmark namespaces for each buffer
local namespaces = {}
-- marks data structure: { file_path -> { branch/global -> { buffer_id -> { extmark_id -> mark_data } } } }
local marks = {}
-- File-based data for restoration: { file_path -> { branch/global -> [ mark_data ] } }
local file_marks_data = {}
local current_branch = nil
local current_git_root = nil
-- Track loaded buffers to prevent duplicate loading
local loaded_buffers = {}

-- Get or create namespace for buffer
local function get_namespace(bufnr)
  if not namespaces[bufnr] then
    namespaces[bufnr] = vim.api.nvim_create_namespace("fusen_buffer_" .. bufnr)
  end
  return namespaces[bufnr]
end

function M.init()
  marks = {}
  file_marks_data = {}
  namespaces = {}
  current_branch = nil
  current_git_root = nil
  loaded_buffers = {}
end

local function get_mark_key(file_path, branch)
  local config = require("fusen.config").get()

  if config.branch_aware and branch then
    return branch
  else
    return "global"
  end
end

-- Helper to initialize nested mark structure
local function ensure_mark_structure(file_path, branch_key, bufnr)
  if not marks[file_path] then
    marks[file_path] = {}
  end
  if not marks[file_path][branch_key] then
    marks[file_path][branch_key] = {}
  end
  if not marks[file_path][branch_key][bufnr] then
    marks[file_path][branch_key][bufnr] = {}
  end
  return marks[file_path][branch_key][bufnr]
end

local function get_buffer_marks(bufnr)
  bufnr = tonumber(bufnr)
  if not bufnr then
    return {}
  end

  local file_path = vim.api.nvim_buf_get_name(bufnr)
  if file_path == "" then
    return {}
  end

  -- Cache file path for later use
  local buffer_key = bufnr .. ":" .. file_path
  loaded_buffers[buffer_key] = true

  local branch, git_root = git.get_branch_info()
  current_branch = branch
  current_git_root = git_root

  local branch_key = get_mark_key(file_path, branch)
  return ensure_mark_structure(file_path, branch_key, bufnr)
end

-- Get current line number for extmark
local function get_extmark_line(bufnr, extmark_id, ns_id)
  local ok, extmarks = pcall(vim.api.nvim_buf_get_extmarks, bufnr, ns_id, extmark_id, extmark_id, {})

  if ok and #extmarks > 0 then
    return extmarks[1][2] + 1 -- Convert 0-indexed to 1-indexed
  end

  return nil
end

function M.add_mark(bufnr, line, annotation)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  local buffer_marks = get_buffer_marks(bufnr)
  local ns_id = get_namespace(bufnr)

  -- Check if mark already exists at this line
  for extmark_id, mark in pairs(buffer_marks) do
    local mark_line = get_extmark_line(bufnr, extmark_id, ns_id)
    if mark_line == line then
      -- Remove existing mark
      vim.api.nvim_buf_del_extmark(bufnr, ns_id, extmark_id)
      buffer_marks[extmark_id] = nil
      return false
    end
  end

  -- Create new extmark
  local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, line - 1, 0, {
    strict = false, -- Allow extmark to survive text changes
  })

  if extmark_id then
    buffer_marks[extmark_id] = {
      annotation = annotation or "",
      created_at = os.time(),
      line = line, -- Store line for shutdown scenarios
    }
    return true
  end

  return false
end

function M.remove_mark(bufnr, line)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  local buffer_marks = get_buffer_marks(bufnr)
  local ns_id = get_namespace(bufnr)

  -- Find mark at specified line
  for extmark_id, mark in pairs(buffer_marks) do
    local mark_line = get_extmark_line(bufnr, extmark_id, ns_id)
    if mark_line == line then
      vim.api.nvim_buf_del_extmark(bufnr, ns_id, extmark_id)
      buffer_marks[extmark_id] = nil
      return true
    end
  end

  return false
end

function M.get_mark(bufnr, line)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return nil
  end

  local buffer_marks = get_buffer_marks(bufnr)
  local ns_id = get_namespace(bufnr)

  for extmark_id, mark in pairs(buffer_marks) do
    local mark_line = get_extmark_line(bufnr, extmark_id, ns_id)
    if mark_line == line then
      return vim.tbl_extend("force", mark, {
        line = mark_line,
        extmark_id = extmark_id,
      })
    end
  end

  return nil
end

function M.get_marks(bufnr)
  if bufnr then
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return {}
    end

    local buffer_marks = get_buffer_marks(bufnr)
    local ns_id = get_namespace(bufnr)
    local result = {}

    for extmark_id, mark in pairs(buffer_marks) do
      local line = get_extmark_line(bufnr, extmark_id, ns_id)
      if line then
        table.insert(
          result,
          vim.tbl_extend("force", mark, {
            line = line,
            extmark_id = extmark_id,
          })
        )
      end
    end

    -- Sort by line number
    table.sort(result, function(a, b)
      return a.line < b.line
    end)

    return result
  end

  -- Get all marks from saved data (file-based, not buffer-dependent)
  local function get_all_marks_from_data()
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

  -- Get all marks across all buffers for current branch
  local all_marks = {}
  local branch = current_branch or git.get_current_branch()
  local branch_key = get_mark_key(nil, branch)

  -- Iterate through all files
  for file_path, file_branches in pairs(marks) do
    -- Check if this file has marks for the current branch
    if file_branches[branch_key] then
      for buf_id, buffer_marks in pairs(file_branches[branch_key]) do
        if vim.api.nvim_buf_is_valid(buf_id) then
          local ns_id = get_namespace(buf_id)

          for extmark_id, mark in pairs(buffer_marks) do
            local line = get_extmark_line(buf_id, extmark_id, ns_id)
            if line then
              table.insert(
                all_marks,
                vim.tbl_extend("force", mark, {
                  line = line,
                  file = file_path,
                  buffer = buf_id,
                  extmark_id = extmark_id,
                })
              )
            end
          end
        end
      end
    end
  end

  -- If no marks found from loaded buffers, try to get from saved data
  if #all_marks == 0 then
    return get_all_marks_from_data()
  end

  return all_marks
end

function M.clear_buffer_marks(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local buffer_marks = get_buffer_marks(bufnr)
  local ns_id = get_namespace(bufnr)

  -- Remove all extmarks
  for extmark_id, _ in pairs(buffer_marks) do
    vim.api.nvim_buf_del_extmark(bufnr, ns_id, extmark_id)
  end

  -- Clear marks data with new structure
  local file_path = vim.api.nvim_buf_get_name(bufnr)
  local branch, _ = git.get_branch_info()
  local branch_key = get_mark_key(file_path, branch)

  if marks[file_path] and marks[file_path][branch_key] and marks[file_path][branch_key][bufnr] then
    marks[file_path][branch_key][bufnr] = {}
  end
end

function M.clear_all_marks()
  -- Clear all marks across all files and branches
  for file_path, file_branches in pairs(marks) do
    for branch_key, branch_buffers in pairs(file_branches) do
      for buf_id, buffer_marks in pairs(branch_buffers) do
        if vim.api.nvim_buf_is_valid(buf_id) then
          local ns_id = get_namespace(buf_id)
          for extmark_id, _ in pairs(buffer_marks) do
            vim.api.nvim_buf_del_extmark(buf_id, ns_id, extmark_id)
          end
        end
      end
    end
  end
  marks = {}
  file_marks_data = {}
end

function M.update_annotation(bufnr, line, annotation)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  local buffer_marks = get_buffer_marks(bufnr)
  local ns_id = get_namespace(bufnr)

  for extmark_id, mark in pairs(buffer_marks) do
    local mark_line = get_extmark_line(bufnr, extmark_id, ns_id)
    if mark_line == line then
      mark.annotation = annotation or ""
      return true
    end
  end

  return false
end

function M.get_next_mark(bufnr, current_line)
  local file_marks = M.get_marks(bufnr)

  if #file_marks == 0 then
    return nil
  end

  for _, mark in ipairs(file_marks) do
    if mark.line > current_line then
      return mark
    end
  end

  return file_marks[1]
end

function M.get_prev_mark(bufnr, current_line)
  local file_marks = M.get_marks(bufnr)

  if #file_marks == 0 then
    return nil
  end

  for i = #file_marks, 1, -1 do
    if file_marks[i].line < current_line then
      return file_marks[i]
    end
  end

  return file_marks[#file_marks]
end

-- For storage compatibility
function M.set_marks_data(data)
  -- Clear existing data
  M.clear_all_marks()
  marks = {}
  file_marks_data = {}

  if not data then
    return
  end

  -- Store file-based data for later restoration (file_path -> branch -> marks)
  file_marks_data = vim.deepcopy(data)

  -- Try to restore marks for already open buffers
  for file_path, branch_data in pairs(data) do
    -- Find buffer for this file path
    local bufnr = nil
    for _, buf_id in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(buf_id) then
        local buf_name = vim.api.nvim_buf_get_name(buf_id)
        if buf_name == file_path then
          bufnr = buf_id
          break
        end
      end
    end

    -- If buffer is loaded, restore extmarks
    if bufnr then
      for branch_key, file_marks in pairs(branch_data) do
        -- Initialize structure for this file/branch/buffer
        if not marks[file_path] then
          marks[file_path] = {}
        end
        if not marks[file_path][branch_key] then
          marks[file_path][branch_key] = {}
        end

        local ns_id = get_namespace(bufnr)
        local new_buffer_marks = {}

        if type(file_marks) == "table" then
          for _, mark_data in ipairs(file_marks) do
            if mark_data.line then
              local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, mark_data.line - 1, 0, {
                strict = false,
              })
              if extmark_id then
                new_buffer_marks[extmark_id] = {
                  annotation = mark_data.annotation or "",
                  created_at = mark_data.created_at or os.time(),
                  line = mark_data.line, -- Store line for shutdown scenarios
                }
              end
            end
          end
        end

        marks[file_path][branch_key][bufnr] = new_buffer_marks
      end

      -- Mark buffer as loaded
      local buffer_key = bufnr .. ":" .. file_path
      loaded_buffers[buffer_key] = true
    end
  end
end

function M.get_marks_data()
  -- Convert extmarks to serializable format with file_path -> branch structure
  local serializable_marks = {}

  -- Iterate through file_path -> branch -> buffer structure
  for file_path, file_branches in pairs(marks) do
    for branch_key, branch_buffers in pairs(file_branches) do
      for buf_id, buffer_marks in pairs(branch_buffers) do
        local buffer_valid = vim.api.nvim_buf_is_valid(buf_id)
        local buffer_marks_array = {}

        if buffer_valid then
          -- Buffer is valid, get current positions from extmarks
          local ns_id = get_namespace(buf_id)
          for extmark_id, mark in pairs(buffer_marks) do
            local line = get_extmark_line(buf_id, extmark_id, ns_id)

            -- Use stored line as fallback if extmark line not available
            local final_line = line or mark.line
            if final_line then
              table.insert(buffer_marks_array, {
                annotation = mark.annotation,
                created_at = mark.created_at,
                line = final_line,
              })
            end
          end
        else
          -- Buffer is invalid (shutdown scenario), use stored data
          for _, mark in pairs(buffer_marks) do
            if mark.line then
              table.insert(buffer_marks_array, {
                annotation = mark.annotation,
                created_at = mark.created_at,
                line = mark.line,
              })
            end
          end
        end

        -- Sort marks by created_at (ascending)
        table.sort(buffer_marks_array, function(a, b)
          return a.created_at < b.created_at
        end)

        -- Only add to serializable_marks if we have marks
        if #buffer_marks_array > 0 then
          if not serializable_marks[file_path] then
            serializable_marks[file_path] = {}
          end
          serializable_marks[file_path][branch_key] = buffer_marks_array
        end
      end
    end
  end

  return serializable_marks
end

function M.get_current_branch_info()
  return current_branch, current_git_root
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

  -- Disable auto_save during restore to prevent infinite loop
  local storage = require("fusen.storage")
  storage.disable_auto_save()

  -- Get branch info
  local branch, _ = git.get_branch_info()
  local branch_key = get_mark_key(file_path, branch)

  -- Use in-memory data with new structure: file_path -> branch
  if not file_marks_data[file_path] or not file_marks_data[file_path][branch_key] then
    storage.enable_auto_save()
    return
  end

  -- Restore marks for this buffer
  local file_marks = file_marks_data[file_path][branch_key]

  local ns_id = get_namespace(bufnr)
  local buffer_marks = get_buffer_marks(bufnr)

  -- Clear existing marks for this buffer
  for extmark_id, _ in pairs(buffer_marks) do
    vim.api.nvim_buf_del_extmark(bufnr, ns_id, extmark_id)
  end
  buffer_marks = {}

  -- Restore marks
  for _, mark_data in ipairs(file_marks) do
    if mark_data.line then
      local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, mark_data.line - 1, 0, {
        strict = false,
      })
      if extmark_id then
        buffer_marks[extmark_id] = {
          annotation = mark_data.annotation or "",
          created_at = mark_data.created_at or os.time(),
          line = mark_data.line, -- Store line for shutdown scenarios
        }
      end
    end
  end

  -- Update marks data with new structure
  if not marks[file_path] then
    marks[file_path] = {}
  end
  if not marks[file_path][branch_key] then
    marks[file_path][branch_key] = {}
  end
  marks[file_path][branch_key][bufnr] = buffer_marks

  -- Re-enable auto_save after restore
  storage.enable_auto_save()
end

-- Clean up extmarks for closed buffers
function M.cleanup_closed_buffers()
  for buf_id, _ in pairs(namespaces) do
    if not vim.api.nvim_buf_is_valid(buf_id) then
      namespaces[buf_id] = nil
      -- Clean from new marks data structure
      for file_path, file_branches in pairs(marks) do
        for branch_key, branch_buffers in pairs(file_branches) do
          if branch_buffers[buf_id] then
            branch_buffers[buf_id] = nil
          end
        end
      end
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
