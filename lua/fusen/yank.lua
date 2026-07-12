local M = {}

-- Valid scopes, exposed for the :FusenYank completion
M.scopes = { "line", "buffer", "all" }

-- Convert an absolute path to a path relative to the current working directory.
-- Falls back to the original path when it cannot be made relative.
local function to_relative_path(absolute_path)
  local relative = vim.fn.fnamemodify(absolute_path, ":.")
  if relative == "" then
    return absolute_path
  end
  return relative
end

-- Render one mark using the configured yank template.
-- Placeholders: {path} {file} {line} {annotation}
-- Unknown placeholders are kept as-is.
local function render(mark, yank_config)
  -- Marks loaded from a hand-edited save file may have a missing or null
  -- annotation; normalize both to an empty string
  local annotation = mark.annotation
  if annotation == nil or annotation == vim.NIL then
    annotation = ""
  end

  local template = annotation == "" and yank_config.template_no_annotation or yank_config.template

  local values = {
    path = to_relative_path(mark.file),
    file = mark.file,
    line = tostring(mark.line),
    annotation = annotation,
  }

  return (template:gsub("{(%w+)}", function(key)
    return values[key]
  end))
end

-- Collect marks for the scope and render them, one line per mark.
-- Returns nil for an invalid scope, an empty table when no marks match.
local function collect(scope)
  local marks = require("fusen.marks")

  local scoped_marks
  if scope == "all" then
    scoped_marks = marks.get_marks()
  elseif scope == "buffer" then
    scoped_marks = marks.get_buffer_marks(vim.api.nvim_get_current_buf())
  elseif scope == "line" then
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    scoped_marks = {}
    for _, mark in ipairs(marks.get_buffer_marks(vim.api.nvim_get_current_buf())) do
      if mark.line == cursor_line then
        table.insert(scoped_marks, mark)
      end
    end
  else
    return nil
  end

  local yank_config = require("fusen.config").get().yank
  local lines = {}
  for _, mark in ipairs(scoped_marks) do
    table.insert(lines, render(mark, yank_config))
  end

  return lines
end

-- Format marks as text, one rendered template per mark, joined with newlines.
-- scope: "line" (mark at cursor) | "buffer" (current buffer) | "all" (project)
-- Returns nil for an invalid scope, an empty string when no marks match.
function M.get_text(scope)
  local lines = collect(scope)
  if not lines then
    return nil
  end
  return table.concat(lines, "\n")
end

-- Copy marks to the system clipboard ("+" register).
function M.yank(scope)
  local lines = collect(scope)
  if lines == nil then
    vim.notify("Invalid scope: " .. tostring(scope) .. " (expected line, buffer or all)", vim.log.levels.ERROR)
    return
  end

  if #lines == 0 then
    vim.notify("No marks to yank", vim.log.levels.INFO)
    return
  end

  -- setreg("+") fails silently without a clipboard provider; check upfront
  if vim.fn.has("clipboard") == 0 then
    vim.notify("No clipboard provider available; cannot yank marks", vim.log.levels.WARN)
    return
  end

  vim.fn.setreg("+", table.concat(lines, "\n"))
  vim.notify("Yanked " .. #lines .. " mark(s) to clipboard", vim.log.levels.INFO)
end

return M
