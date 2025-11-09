describe("fusen.storage", function()
  local storage
  local mock_save_file = "/tmp/fusen_test_marks.json"

  -- Store original functions
  local original_io_open
  local original_mkdir
  local original_fnamemodify

  -- Virtual file system
  local virtual_fs = {}

  -- Mock file object
  local function create_mock_file(path, mode, content)
    local file_obj = {
      content = content or "",
      closed = false,
      pending_buffer = "", -- Data written but not yet flushed
      path = path,
    }

    function file_obj:read(format)
      if self.closed then
        error("attempt to use a closed file")
      end
      if format == "*a" then
        return self.content
      end
      return self.content
    end

    function file_obj:write(data)
      if self.closed then
        error("attempt to use a closed file")
      end
      -- Write to pending buffer, not directly to virtual_fs
      self.pending_buffer = self.pending_buffer .. data
      return true
    end

    function file_obj:flush()
      if self.closed then
        error("attempt to use a closed file")
      end
      -- Flush commits pending data to virtual_fs
      if self.pending_buffer ~= "" then
        virtual_fs[self.path] = self.pending_buffer
      end
      return true
    end

    function file_obj:close()
      if not self.closed then
        -- Close also commits pending data
        if self.pending_buffer ~= "" then
          virtual_fs[self.path] = self.pending_buffer
        end
        self.closed = true
      end
      return true
    end

    return file_obj
  end

  -- Mock marks module state
  local mock_marks_data = {}
  local mock_init_called = false
  local mock_set_marks_data_called = false
  local mock_set_marks_data_arg = nil

  before_each(function()
    -- Clear module cache
    package.loaded["fusen.storage"] = nil
    package.loaded["fusen.config"] = nil
    package.loaded["fusen.marks"] = nil
    package.loaded["fusen.ui"] = nil

    -- Reset virtual file system
    virtual_fs = {}

    -- Reset mock state
    mock_marks_data = {}
    mock_init_called = false
    mock_set_marks_data_called = false
    mock_set_marks_data_arg = nil

    -- Store original functions
    original_io_open = io.open
    original_mkdir = vim.fn.mkdir
    original_fnamemodify = vim.fn.fnamemodify

    -- Mock io.open
    io.open = function(path, mode)
      if mode == "r" then
        -- Read mode
        if virtual_fs[path] then
          return create_mock_file(path, mode, virtual_fs[path])
        else
          return nil
        end
      elseif mode == "w" then
        -- Write mode
        return create_mock_file(path, mode)
      end
      return nil
    end

    -- Mock vim.fn.mkdir
    vim.fn.mkdir = function(dir, opts)
      -- Mock directory creation - always succeed
      return 1
    end

    -- Mock vim.fn.fnamemodify
    vim.fn.fnamemodify = function(path, modifier)
      if modifier == ":h" then
        -- Return directory part
        return path:match("(.*/)") or "."
      end
      return path
    end

    -- Mock config module
    package.loaded["fusen.config"] = {
      get = function()
        return {
          save_file = mock_save_file,
        }
      end,
    }

    -- Mock marks module
    package.loaded["fusen.marks"] = {
      get_marks_data = function()
        return mock_marks_data
      end,
      set_marks_data = function(data)
        mock_set_marks_data_called = true
        mock_set_marks_data_arg = data
      end,
      init = function()
        mock_init_called = true
      end,
    }

    -- Mock ui module
    package.loaded["fusen.ui"] = {
      refresh_all_buffers = function()
        -- No-op for tests
      end,
    }

    -- Load storage module
    storage = require("fusen.storage")
  end)

  after_each(function()
    -- Restore original functions
    io.open = original_io_open
    vim.fn.mkdir = original_mkdir
    vim.fn.fnamemodify = original_fnamemodify
  end)

  describe("save", function()
    it("should save marks data to file", function()
      mock_marks_data = {
        ["/tmp/test.lua"] = {
          ["main"] = {
            { line = 10, annotation = "test", created_at = 123456 },
          },
        },
      }

      local result = storage.save()

      assert.is_true(result)
      assert.is_not_nil(virtual_fs[mock_save_file])
    end)

    it("should save valid JSON", function()
      mock_marks_data = {
        ["/tmp/test.lua"] = {
          ["main"] = {
            { line = 10, annotation = "test", created_at = 123456 },
          },
        },
      }

      storage.save()

      local saved_content = virtual_fs[mock_save_file]
      local ok, decoded = pcall(vim.json.decode, saved_content)
      assert.is_true(ok)
      assert.is_not_nil(decoded["/tmp/test.lua"])
      assert.is_not_nil(decoded["/tmp/test.lua"]["main"])
      assert.are.equal(1, #decoded["/tmp/test.lua"]["main"])
      assert.are.equal(10, decoded["/tmp/test.lua"]["main"][1].line)
    end)

    it("should save empty marks data", function()
      mock_marks_data = {}

      local result = storage.save()

      assert.is_true(result)
      local saved_content = virtual_fs[mock_save_file]
      local ok, decoded = pcall(vim.json.decode, saved_content)
      assert.is_true(ok)
      assert.is_nil(next(decoded))
    end)

    it("should overwrite existing file", function()
      -- Pre-populate virtual file system
      virtual_fs[mock_save_file] = '{"old":"data"}'

      mock_marks_data = {
        ["/tmp/test.lua"] = {
          ["main"] = {
            { line = 5, annotation = "new", created_at = 999 },
          },
        },
      }

      storage.save()

      local saved_content = virtual_fs[mock_save_file]
      local ok, decoded = pcall(vim.json.decode, saved_content)
      assert.is_true(ok)
      assert.is_nil(decoded["old"])
      assert.is_not_nil(decoded["/tmp/test.lua"])
    end)

    it("should return false when file write fails", function()
      -- Mock io.open to fail for write mode
      io.open = function(path, mode)
        if mode == "w" then
          return nil
        end
        return original_io_open(path, mode)
      end

      mock_marks_data = { test = "data" }

      local result = storage.save()

      assert.is_false(result)
    end)

    it("should handle complex nested data", function()
      mock_marks_data = {
        ["/tmp/file1.lua"] = {
          ["main"] = {
            { line = 10, annotation = "mark1", created_at = 111 },
            { line = 20, annotation = "mark2", created_at = 222 },
          },
          ["feature"] = {
            { line = 15, annotation = "branch-mark", created_at = 333 },
          },
        },
        ["/tmp/file2.lua"] = {
          ["main"] = {
            { line = 5, annotation = "another", created_at = 444 },
          },
        },
      }

      local result = storage.save()

      assert.is_true(result)
      local saved_content = virtual_fs[mock_save_file]
      local ok, decoded = pcall(vim.json.decode, saved_content)
      assert.is_true(ok)
      assert.are.equal(2, #decoded["/tmp/file1.lua"]["main"])
      assert.are.equal(1, #decoded["/tmp/file1.lua"]["feature"])
      assert.are.equal(1, #decoded["/tmp/file2.lua"]["main"])
    end)
  end)

  describe("load", function()
    it("should load marks data from file", function()
      local test_data = {
        ["/tmp/test.lua"] = {
          ["main"] = {
            { line = 10, annotation = "test", created_at = 123456 },
          },
        },
      }

      virtual_fs[mock_save_file] = vim.json.encode(test_data)

      local result = storage.load()

      assert.is_true(result)
      assert.is_true(mock_set_marks_data_called)
      assert.is_not_nil(mock_set_marks_data_arg)
      assert.is_not_nil(mock_set_marks_data_arg["/tmp/test.lua"])
    end)

    it("should call marks.init when file does not exist", function()
      -- File doesn't exist in virtual_fs

      local result = storage.load()

      assert.is_true(result)
      assert.is_true(mock_init_called)
      assert.is_false(mock_set_marks_data_called)
    end)

    it("should call marks.init when file is empty", function()
      virtual_fs[mock_save_file] = ""

      local result = storage.load()

      assert.is_true(result)
      assert.is_true(mock_init_called)
      assert.is_false(mock_set_marks_data_called)
    end)

    it("should call marks.init when JSON is invalid", function()
      virtual_fs[mock_save_file] = "{ invalid json }"

      local result = storage.load()

      assert.is_true(result)
      assert.is_true(mock_init_called)
      assert.is_false(mock_set_marks_data_called)
    end)

    it("should load empty marks data", function()
      virtual_fs[mock_save_file] = "{}"

      local result = storage.load()

      assert.is_true(result)
      assert.is_true(mock_set_marks_data_called)
      assert.is_nil(next(mock_set_marks_data_arg))
    end)

    it("should load complex nested data", function()
      local test_data = {
        ["/tmp/file1.lua"] = {
          ["main"] = {
            { line = 10, annotation = "mark1", created_at = 111 },
            { line = 20, annotation = "mark2", created_at = 222 },
          },
          ["feature"] = {
            { line = 15, annotation = "branch-mark", created_at = 333 },
          },
        },
        ["/tmp/file2.lua"] = {
          ["main"] = {
            { line = 5, annotation = "another", created_at = 444 },
          },
        },
      }

      virtual_fs[mock_save_file] = vim.json.encode(test_data)

      local result = storage.load()

      assert.is_true(result)
      assert.is_true(mock_set_marks_data_called)
      assert.are.equal(2, #mock_set_marks_data_arg["/tmp/file1.lua"]["main"])
      assert.are.equal(1, #mock_set_marks_data_arg["/tmp/file1.lua"]["feature"])
      assert.are.equal(1, #mock_set_marks_data_arg["/tmp/file2.lua"]["main"])
    end)

    it("should always return true", function()
      -- Even on error, load() should return true
      virtual_fs[mock_save_file] = "invalid"

      local result = storage.load()

      assert.is_true(result)
    end)
  end)

  describe("setup_autocmds", function()
    it("should create autocommand group", function()
      local group_created = false
      local original_create_augroup = vim.api.nvim_create_augroup

      vim.api.nvim_create_augroup = function(name, opts)
        if name == "FusenStorage" then
          group_created = true
        end
        return original_create_augroup(name, opts)
      end

      storage.setup_autocmds()

      assert.is_true(group_created)

      vim.api.nvim_create_augroup = original_create_augroup
    end)

    it("should register FocusGained autocmd", function()
      local autocmd_registered = false
      local autocmd_events = nil
      local original_create_autocmd = vim.api.nvim_create_autocmd

      vim.api.nvim_create_autocmd = function(events, opts)
        autocmd_events = events
        autocmd_registered = true
        return original_create_autocmd(events, opts)
      end

      storage.setup_autocmds()

      assert.is_true(autocmd_registered)
      assert.is_not_nil(autocmd_events)
      assert.are.equal("FocusGained", autocmd_events[1])

      vim.api.nvim_create_autocmd = original_create_autocmd
    end)

    it("should not error when called", function()
      -- Just verify it doesn't throw
      storage.setup_autocmds()
    end)
  end)

  describe("save and load integration", function()
    it("should be able to save and load the same data", function()
      -- Setup initial data
      mock_marks_data = {
        ["/tmp/test.lua"] = {
          ["main"] = {
            { line = 10, annotation = "test", created_at = 123456 },
            { line = 20, annotation = "test2", created_at = 789012 },
          },
        },
      }

      -- Save
      local save_result = storage.save()
      assert.is_true(save_result)

      -- Load
      local load_result = storage.load()
      assert.is_true(load_result)
      assert.is_true(mock_set_marks_data_called)

      -- Verify data matches
      local loaded_data = mock_set_marks_data_arg
      assert.is_not_nil(loaded_data["/tmp/test.lua"])
      assert.is_not_nil(loaded_data["/tmp/test.lua"]["main"])
      assert.are.equal(2, #loaded_data["/tmp/test.lua"]["main"])
      assert.are.equal(10, loaded_data["/tmp/test.lua"]["main"][1].line)
      assert.are.equal("test", loaded_data["/tmp/test.lua"]["main"][1].annotation)
      assert.are.equal(20, loaded_data["/tmp/test.lua"]["main"][2].line)
      assert.are.equal("test2", loaded_data["/tmp/test.lua"]["main"][2].annotation)
    end)
  end)
end)
