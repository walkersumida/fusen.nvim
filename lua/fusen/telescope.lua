local M = {}

local function telescope_available()
  return pcall(require, "telescope")
end

function M.setup()
  if not telescope_available() then
    return false
  end

  local telescope = require("telescope")
  telescope.load_extension("fusen")
  return true
end

function M.marks_picker(opts)
  if not telescope_available() then
    vim.notify("Telescope is not installed", vim.log.levels.WARN)
    return
  end

  opts = opts or {}

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local entry_display = require("telescope.pickers.entry_display")
  local previewers = require("telescope.previewers")

  local marks = require("fusen.marks")
  local config = require("fusen.config").get()
  local all_marks = marks.get_marks()

  if #all_marks == 0 then
    vim.notify("No marks found", vim.log.levels.INFO)
    return
  end

  table.sort(all_marks, function(a, b)
    if a.file == b.file then
      return a.line < b.line
    end
    return a.file < b.file
  end)

  local displayer = entry_display.create({
    separator = " ",
    items = {
      { width = 3 },
      { width = 40 },
      { width = 5 },
      { remaining = true },
    },
  })

  local function make_display(entry)
    local mark = entry.value

    return displayer({
      { config.mark.icon, config.mark.hl_group },
      { mark.annotation or "(no annotation)", "TelescopeResultsComment" },
      { tostring(mark.line), "TelescopeResultsNumber" },
      { vim.fn.fnamemodify(mark.file, ":."), "TelescopeResultsIdentifier" },
    })
  end

  pickers
    .new(opts, {
      prompt_title = "Fusen Marks",
      finder = finders.new_table({
        results = all_marks,
        entry_maker = function(mark)
          return {
            value = mark,
            display = make_display,
            ordinal = string.format("%s:%d %s", mark.file, mark.line, mark.annotation or ""),
            filename = mark.file,
            lnum = mark.line,
            col = 1,
          }
        end,
      }),
      sorter = conf.generic_sorter(opts),
      previewer = previewers.new_buffer_previewer({
        title = "Mark Preview",
        get_buffer_by_name = function(_, entry)
          return entry.filename
        end,
        define_preview = function(self, entry, status)
          local bufnr = self.state.bufnr
          local mark = entry.value

          -- Load file content
          conf.buffer_previewer_maker(entry.filename, bufnr, {
            bufname = self.state.bufname,
            winid = status.preview_win,
          })

          -- Highlight the mark line after content is loaded
          vim.defer_fn(function()
            if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_win_is_valid(status.preview_win) then
              local line_count = vim.api.nvim_buf_line_count(bufnr)
              local target_line = math.min(mark.line, line_count)

              if target_line > 0 and target_line <= line_count then
                -- Highlight the mark line
                vim.api.nvim_win_call(status.preview_win, function()
                  pcall(vim.fn.clearmatches)
                  vim.fn.matchadd("IncSearch", "\\%" .. target_line .. "l", 10)
                end)

                -- Set cursor to the mark line and center it
                pcall(vim.api.nvim_win_set_cursor, status.preview_win, { target_line, 0 })
                vim.api.nvim_win_call(status.preview_win, function()
                  vim.cmd("normal! zz")
                end)
              end
            end
          end, 100)
        end,
      }),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection then
            vim.cmd(string.format("edit +%d %s", selection.lnum, selection.filename))
          end
        end)

        map("i", "<C-d>", function()
          local selection = action_state.get_selected_entry()
          if selection then
            -- Find buffer for the file
            local bufnr = nil
            for _, buf_id in ipairs(vim.api.nvim_list_bufs()) do
              if vim.api.nvim_buf_is_valid(buf_id) then
                local buf_name = vim.api.nvim_buf_get_name(buf_id)
                if buf_name == selection.value.file then
                  bufnr = buf_id
                  break
                end
              end
            end

            if bufnr then
              marks.remove_mark(bufnr, selection.value.line)
              local ui = require("fusen.ui")
              ui.refresh_all_buffers()
              local storage = require("fusen.storage")
              storage.auto_save()
              vim.notify(
                string.format("Removed mark at %s:%d", selection.value.file, selection.value.line),
                vim.log.levels.INFO
              )
            else
              vim.notify(string.format("Buffer not found for %s", selection.value.file), vim.log.levels.WARN)
            end
          end
        end)

        return true
      end,
    })
    :find()
end

-- Extension registration is now handled in lua/telescope/_extensions/fusen.lua

return M
