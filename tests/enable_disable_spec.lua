describe("fusen enable/disable/toggle", function()
  local fusen
  local ui
  local config
  local original_notify
  local captured_notify_msg
  local captured_notify_level

  before_each(function()
    -- Clear module cache
    package.loaded["fusen"] = nil
    package.loaded["fusen.config"] = nil
    package.loaded["fusen.marks"] = nil
    package.loaded["fusen.ui"] = nil
    package.loaded["fusen.storage"] = nil
    package.loaded["fusen.git"] = nil

    -- Mock vim.notify
    original_notify = vim.notify
    vim.notify = function(msg, level)
      captured_notify_msg = msg
      captured_notify_level = level
    end

    -- Load modules
    fusen = require("fusen")
    ui = require("fusen.ui")
    config = require("fusen.config")

    -- Mock ui.refresh_all_buffers and ui.clear_all_buffers
    ui.refresh_all_buffers = function() end
    ui.clear_all_buffers = function() end

    -- Setup with test configuration
    fusen.setup({
      save_file = "/tmp/test_fusen_marks.json",
    })

    -- Reset captured values
    captured_notify_msg = nil
    captured_notify_level = nil
  end)

  after_each(function()
    -- Restore original functions
    vim.notify = original_notify
  end)

  describe("enable", function()
    it("should set enabled to true in config", function()
      -- Arrange
      local cfg = config.get()
      cfg.enabled = false

      -- Act
      fusen.enable()

      -- Assert
      assert.is_true(cfg.enabled)
    end)

    it("should show notification when enabled", function()
      -- Act
      fusen.enable()

      -- Assert
      assert.are.equal("Fusen enabled", captured_notify_msg)
      assert.are.equal(vim.log.levels.INFO, captured_notify_level)
    end)
  end)

  describe("disable", function()
    it("should set enabled to false in config", function()
      -- Arrange
      local cfg = config.get()
      cfg.enabled = true

      -- Act
      fusen.disable()

      -- Assert
      assert.is_false(cfg.enabled)
    end)

    it("should show notification when disabled", function()
      -- Act
      fusen.disable()

      -- Assert
      assert.are.equal("Fusen disabled", captured_notify_msg)
      assert.are.equal(vim.log.levels.INFO, captured_notify_level)
    end)
  end)

  describe("toggle", function()
    it("should toggle from enabled to disabled", function()
      -- Arrange
      local cfg = config.get()
      cfg.enabled = true

      -- Act
      fusen.toggle()

      -- Assert
      assert.is_false(cfg.enabled)
      assert.are.equal("Fusen disabled", captured_notify_msg)
    end)

    it("should toggle from disabled to enabled", function()
      -- Arrange
      local cfg = config.get()
      cfg.enabled = false

      -- Act
      fusen.toggle()

      -- Assert
      assert.is_true(cfg.enabled)
      assert.are.equal("Fusen enabled", captured_notify_msg)
    end)
  end)

  describe("operations when disabled", function()
    before_each(function()
      -- Disable fusen
      fusen.disable()
      captured_notify_msg = nil
    end)

    it("should block add_mark when disabled", function()
      -- Act
      fusen.add_mark()

      -- Assert
      assert.are.equal("Fusen is currently disabled", captured_notify_msg)
      assert.are.equal(vim.log.levels.WARN, captured_notify_level)
    end)

    it("should block clear_mark when disabled", function()
      -- Act
      fusen.clear_mark()

      -- Assert
      assert.are.equal("Fusen is currently disabled", captured_notify_msg)
      assert.are.equal(vim.log.levels.WARN, captured_notify_level)
    end)

    it("should block clear_buffer when disabled", function()
      -- Act
      fusen.clear_buffer()

      -- Assert
      assert.are.equal("Fusen is currently disabled", captured_notify_msg)
      assert.are.equal(vim.log.levels.WARN, captured_notify_level)
    end)

    it("should block clear_all when disabled", function()
      -- Act
      fusen.clear_all()

      -- Assert
      assert.are.equal("Fusen is currently disabled", captured_notify_msg)
      assert.are.equal(vim.log.levels.WARN, captured_notify_level)
    end)
  end)
end)
