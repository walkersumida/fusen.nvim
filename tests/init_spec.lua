describe("fusen", function()
  local fusen
  local original_cmd_edit
  local original_notify
  local captured_edit_path
  local captured_notify_msg

  before_each(function()
    -- Clear module cache
    package.loaded["fusen"] = nil
    package.loaded["fusen.config"] = nil
    package.loaded["fusen.marks"] = nil
    package.loaded["fusen.ui"] = nil
    package.loaded["fusen.storage"] = nil
    package.loaded["fusen.git"] = nil

    -- Mock vim.cmd.edit
    original_cmd_edit = vim.cmd.edit
    vim.cmd.edit = function(path)
      captured_edit_path = path
    end

    -- Mock vim.notify
    original_notify = vim.notify
    vim.notify = function(msg, level)
      captured_notify_msg = msg
    end

    -- Load modules
    fusen = require("fusen")

    -- Setup with test configuration
    fusen.setup({
      save_file = "/tmp/test_fusen_marks.json",
    })

    -- Reset captured values
    captured_edit_path = nil
    captured_notify_msg = nil
  end)

  after_each(function()
    -- Restore original functions
    vim.cmd.edit = original_cmd_edit
    vim.notify = original_notify
  end)

  describe("toggle_mark", function()
    local marks_mod
    local ui_mod
    local storage_mod
    local config_mod
    local test_buf

    before_each(function()
      marks_mod = require("fusen.marks")
      ui_mod = require("fusen.ui")
      storage_mod = require("fusen.storage")
      config_mod = require("fusen.config")

      -- Create a named buffer for tests
      test_buf = vim.api.nvim_create_buf(true, false)
      vim.api.nvim_buf_set_name(test_buf, "/tmp/test_toggle_mark.lua")
      vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "line1", "line2", "line3" })
      vim.api.nvim_set_current_buf(test_buf)

      -- Mock dependencies
      ui_mod.refresh_buffer = function() end
      storage_mod.save = function() end
    end)

    after_each(function()
      if vim.api.nvim_buf_is_valid(test_buf) then
        vim.api.nvim_buf_delete(test_buf, { force = true })
      end
    end)

    it("should add mark via input_annotation when no mark exists", function()
      -- Arrange
      local input_called = false
      local input_bufnr
      ui_mod.input_annotation = function(bufnr, line, callback)
        input_called = true
        input_bufnr = bufnr
        callback("test annotation")
      end

      -- Act
      fusen.toggle_mark()

      -- Assert
      assert.is_true(input_called)
      assert.are.equal(test_buf, input_bufnr)
      assert.are.equal("Added mark", captured_notify_msg)
    end)

    it("should remove mark with skip_confirm when mark exists", function()
      -- Arrange
      local cfg = config_mod.get()
      cfg.toggle_mark.skip_confirm = true

      local line = vim.api.nvim_win_get_cursor(0)[1]
      marks_mod.add_mark(test_buf, line, "test")

      -- Act
      fusen.toggle_mark()

      -- Assert
      assert.are.equal("Removed mark", captured_notify_msg)
      assert.is_nil(marks_mod.get_mark(test_buf, line))
    end)

    it("should not remove mark when confirmation is rejected", function()
      -- Arrange
      local cfg = config_mod.get()
      cfg.toggle_mark.skip_confirm = false

      local line = vim.api.nvim_win_get_cursor(0)[1]
      marks_mod.add_mark(test_buf, line, "test")

      -- Mock vim.fn.getchar to simulate 'n' (reject)
      local original_getchar = vim.fn.getchar
      vim.fn.getchar = function() return string.byte("n") end

      -- Act
      fusen.toggle_mark()

      -- Assert
      assert.is_not_nil(marks_mod.get_mark(test_buf, line))

      -- Restore
      vim.fn.getchar = original_getchar
    end)

    it("should remove mark when confirmation is accepted", function()
      -- Arrange
      local cfg = config_mod.get()
      cfg.toggle_mark.skip_confirm = false

      local line = vim.api.nvim_win_get_cursor(0)[1]
      marks_mod.add_mark(test_buf, line, "test")

      -- Mock vim.fn.getchar to simulate 'y' (accept)
      local original_getchar = vim.fn.getchar
      vim.fn.getchar = function() return string.byte("y") end

      -- Act
      fusen.toggle_mark()

      -- Assert
      assert.are.equal("Removed mark", captured_notify_msg)
      assert.is_nil(marks_mod.get_mark(test_buf, line))

      -- Restore
      vim.fn.getchar = original_getchar
    end)

    it("should show error on unnamed buffer", function()
      -- Arrange
      local unnamed_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_current_buf(unnamed_buf)

      -- Act
      fusen.toggle_mark()

      -- Assert
      assert.are.equal("Cannot operate on unnamed buffer", captured_notify_msg)

      -- Cleanup
      vim.api.nvim_set_current_buf(test_buf)
      vim.api.nvim_buf_delete(unnamed_buf, { force = true })
    end)

    it("should call storage.save after adding mark", function()
      -- Arrange
      local save_called = false
      storage_mod.save = function()
        save_called = true
      end
      ui_mod.input_annotation = function(bufnr, line, callback)
        callback("annotation")
      end

      -- Act
      fusen.toggle_mark()

      -- Assert
      assert.is_true(save_called)
    end)

    it("should call storage.save after removing mark", function()
      -- Arrange
      local cfg = config_mod.get()
      cfg.toggle_mark.skip_confirm = true

      local save_called = false
      storage_mod.save = function()
        save_called = true
      end

      local line = vim.api.nvim_win_get_cursor(0)[1]
      marks_mod.add_mark(test_buf, line, "test")
      save_called = false

      -- Act
      fusen.toggle_mark()

      -- Assert
      assert.is_true(save_called)
    end)
  end)

  describe("open_save_file", function()
    it("should open the configured save file", function()
      -- Act
      fusen.open_save_file()

      -- Assert
      assert.are.equal("/tmp/test_fusen_marks.json", captured_edit_path)
    end)

    it("should show notification with file path", function()
      -- Act
      fusen.open_save_file()

      -- Assert
      assert.are.equal("Opened: /tmp/test_fusen_marks.json", captured_notify_msg)
    end)

    it("should use default save file when not configured", function()
      -- Setup with no custom save_file
      package.loaded["fusen"] = nil
      package.loaded["fusen.config"] = nil
      fusen = require("fusen")
      fusen.setup({})

      -- Act
      fusen.open_save_file()

      -- Assert
      local expected_path = vim.fn.expand("$HOME") .. "/fusen_marks.json"
      assert.are.equal(expected_path, captured_edit_path)
      assert.are.equal("Opened: " .. expected_path, captured_notify_msg)
    end)
  end)
end)
