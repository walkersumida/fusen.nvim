local M = {}

local function get_save_file()
  local config = require("fusen.config").get()
  return config.save_file
end

local function read_file(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end

  local content = file:read("*a")
  file:close()

  if content and content ~= "" then
    local ok, data = pcall(vim.json.decode, content)
    if ok then
      return data
    end
  end

  return nil
end

local function write_file(path, data)
  -- Check directory permissions and create if needed
  local dir = vim.fn.fnamemodify(path, ":h")
  vim.fn.mkdir(dir, "p")

  local ok, json = pcall(vim.json.encode, data)
  if not ok then
    return false
  end

  local file = io.open(path, "w")
  if not file then
    return false
  end

  local write_ok = pcall(function()
    file:write(json)
    file:flush()
    file:close()
  end)

  return write_ok
end

function M.save()
  local marks = require("fusen.marks")
  local current_marks = marks.get_marks_data()

  local save_file = get_save_file()
  return write_file(save_file, current_marks)
end

function M.load()
  local marks = require("fusen.marks")
  local save_file = get_save_file()

  local data = read_file(save_file)
  if not data then
    marks.init()
    return true
  end

  marks.set_marks_data(data)

  return true
end

function M.setup_autocmds()
  local group = vim.api.nvim_create_augroup("FusenStorage", { clear = true })

  -- Optional: Reload marks when Neovim gains focus (for multi-instance sync)
  vim.api.nvim_create_autocmd({ "FocusGained" }, {
    group = group,
    callback = function()
      -- Reload marks from file to get changes from other instances
      local existing_data = read_file(get_save_file())
      if existing_data then
        local marks = require("fusen.marks")
        marks.set_marks_data(existing_data)
        require("fusen.ui").refresh_all_buffers()
      end
    end,
  })
end

return M
