describe("fusen.yank", function()
  local yank
  local config
  local cwd
  local marks_fixture

  -- Store original functions
  local original_nvim_buf_get_name
  local original_nvim_win_get_cursor
  local original_setreg
  local original_has
  local original_notify

  -- Captured calls
  local setreg_calls
  local notify_messages

  before_each(function()
    -- Clear module cache
    package.loaded["fusen.yank"] = nil
    package.loaded["fusen.marks"] = nil
    package.loaded["fusen.config"] = nil

    cwd = vim.fn.getcwd()
    marks_fixture = {}
    setreg_calls = {}
    notify_messages = {}

    -- Mock marks module with the two queries yank depends on
    package.loaded["fusen.marks"] = {
      get_marks = function()
        return marks_fixture
      end,
      get_buffer_marks = function(bufnr)
        local file = vim.api.nvim_buf_get_name(bufnr)
        local result = {}
        for _, mark in ipairs(marks_fixture) do
          if mark.file == file then
            table.insert(result, mark)
          end
        end
        table.sort(result, function(a, b)
          return a.line < b.line
        end)
        return result
      end,
    }

    original_nvim_buf_get_name = vim.api.nvim_buf_get_name
    original_nvim_win_get_cursor = vim.api.nvim_win_get_cursor
    original_setreg = vim.fn.setreg
    original_has = vim.fn.has
    original_notify = vim.notify

    vim.fn.setreg = function(reg, text)
      table.insert(setreg_calls, { reg = reg, text = text })
    end
    vim.fn.has = function(feature)
      if feature == "clipboard" then
        return 1
      end
      return original_has(feature)
    end
    vim.notify = function(msg)
      table.insert(notify_messages, msg)
    end

    config = require("fusen.config")
    config.setup({})

    yank = require("fusen.yank")
  end)

  after_each(function()
    vim.api.nvim_buf_get_name = original_nvim_buf_get_name
    vim.api.nvim_win_get_cursor = original_nvim_win_get_cursor
    vim.fn.setreg = original_setreg
    vim.fn.has = original_has
    vim.notify = original_notify
    package.loaded["fusen.marks"] = nil
    package.loaded["fusen.yank"] = nil
    package.loaded["fusen.config"] = nil
  end)

  describe("get_text", function()
    it("should format all marks with the default template", function()
      marks_fixture = {
        { file = cwd .. "/lua/foo.lua", line = 10, annotation = "first note" },
        { file = cwd .. "/src/bar.lua", line = 3, annotation = "second note" },
      }

      local expected = '- @lua/foo.lua:L10 - "first note"\n- @src/bar.lua:L3 - "second note"'
      assert.are.equal(expected, yank.get_text("all"))
    end)

    it("should use template_no_annotation for marks without annotation", function()
      marks_fixture = {
        { file = cwd .. "/lua/foo.lua", line = 5, annotation = "" },
      }

      assert.are.equal("- @lua/foo.lua:L5", yank.get_text("all"))
    end)

    it("should treat a nil annotation as empty", function()
      marks_fixture = {
        { file = cwd .. "/lua/foo.lua", line = 5 },
      }

      assert.are.equal("- @lua/foo.lua:L5", yank.get_text("all"))
    end)

    it("should treat a vim.NIL annotation as empty", function()
      marks_fixture = {
        { file = cwd .. "/lua/foo.lua", line = 5, annotation = vim.NIL },
      }

      assert.are.equal("- @lua/foo.lua:L5", yank.get_text("all"))
    end)

    it("should return nil for an invalid scope", function()
      marks_fixture = {
        { file = cwd .. "/lua/foo.lua", line = 10, annotation = "note" },
      }

      assert.is_nil(yank.get_text("typo"))
    end)

    it("should return only current buffer marks for buffer scope", function()
      marks_fixture = {
        { file = cwd .. "/lua/foo.lua", line = 10, annotation = "current" },
        { file = cwd .. "/src/bar.lua", line = 3, annotation = "other" },
      }

      vim.api.nvim_buf_get_name = function()
        return cwd .. "/lua/foo.lua"
      end

      assert.are.equal('- @lua/foo.lua:L10 - "current"', yank.get_text("buffer"))
    end)

    it("should return only the mark at the cursor line for line scope", function()
      marks_fixture = {
        { file = cwd .. "/lua/foo.lua", line = 10, annotation = "at cursor" },
        { file = cwd .. "/lua/foo.lua", line = 20, annotation = "other line" },
      }

      vim.api.nvim_buf_get_name = function()
        return cwd .. "/lua/foo.lua"
      end
      vim.api.nvim_win_get_cursor = function()
        return { 10, 0 }
      end

      assert.are.equal('- @lua/foo.lua:L10 - "at cursor"', yank.get_text("line"))
    end)

    it("should return empty string when no mark at cursor line", function()
      marks_fixture = {
        { file = cwd .. "/lua/foo.lua", line = 10, annotation = "note" },
      }

      vim.api.nvim_buf_get_name = function()
        return cwd .. "/lua/foo.lua"
      end
      vim.api.nvim_win_get_cursor = function()
        return { 5, 0 }
      end

      assert.are.equal("", yank.get_text("line"))
    end)

    it("should apply a custom template from config", function()
      config.setup({
        yank = {
          template = "{file}:{line} {annotation}",
        },
      })

      marks_fixture = {
        { file = cwd .. "/lua/foo.lua", line = 10, annotation = "note" },
      }

      assert.are.equal(cwd .. "/lua/foo.lua:10 note", yank.get_text("all"))
    end)

    it("should keep unknown placeholders as-is", function()
      config.setup({
        yank = {
          template = "{path} {unknown} {annotation}",
        },
      })

      marks_fixture = {
        { file = cwd .. "/lua/foo.lua", line = 10, annotation = "note" },
      }

      assert.are.equal("lua/foo.lua {unknown} note", yank.get_text("all"))
    end)
  end)

  describe("yank", function()
    it("should copy marks to the + register and notify the count", function()
      marks_fixture = {
        { file = cwd .. "/lua/foo.lua", line = 10, annotation = "first" },
        { file = cwd .. "/src/bar.lua", line = 3, annotation = "second" },
      }

      yank.yank("all")

      assert.are.equal(1, #setreg_calls)
      assert.are.equal("+", setreg_calls[1].reg)
      assert.are.equal('- @lua/foo.lua:L10 - "first"\n- @src/bar.lua:L3 - "second"', setreg_calls[1].text)
      assert.are.equal("Yanked 2 mark(s) to clipboard", notify_messages[1])
    end)

    it("should count marks correctly with a multi-line template", function()
      config.setup({
        yank = {
          template = "{path}:{line}\n  {annotation}",
        },
      })

      marks_fixture = {
        { file = cwd .. "/lua/foo.lua", line = 10, annotation = "first" },
        { file = cwd .. "/src/bar.lua", line = 3, annotation = "second" },
      }

      yank.yank("all")

      assert.are.equal("Yanked 2 mark(s) to clipboard", notify_messages[1])
    end)

    it("should not touch the register when there are no marks", function()
      vim.api.nvim_buf_get_name = function()
        return cwd .. "/lua/foo.lua"
      end
      vim.api.nvim_win_get_cursor = function()
        return { 1, 0 }
      end

      yank.yank("line")

      assert.are.equal(0, #setreg_calls)
      assert.are.equal("No marks to yank", notify_messages[1])
    end)

    it("should reject an invalid scope", function()
      marks_fixture = {
        { file = cwd .. "/lua/foo.lua", line = 10, annotation = "note" },
      }

      yank.yank("typo")

      assert.are.equal(0, #setreg_calls)
      assert.is_truthy(notify_messages[1]:match("Invalid scope"))
    end)

    it("should warn instead of reporting success when no clipboard provider exists", function()
      vim.fn.has = function(feature)
        if feature == "clipboard" then
          return 0
        end
        return original_has(feature)
      end

      marks_fixture = {
        { file = cwd .. "/lua/foo.lua", line = 10, annotation = "note" },
      }

      yank.yank("all")

      assert.are.equal(0, #setreg_calls)
      assert.is_truthy(notify_messages[1]:match("No clipboard provider"))
    end)
  end)
end)
