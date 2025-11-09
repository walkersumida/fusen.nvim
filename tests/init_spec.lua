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
