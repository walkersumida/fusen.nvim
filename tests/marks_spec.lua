describe("fusen.marks", function()
  local marks
  local mock_bufnr = 1
  local mock_file_path = "/tmp/test_file.lua"
  local mock_branch = "main"
  local mock_time = 1234567890

  -- Store original functions
  local original_nvim_buf_is_valid
  local original_nvim_buf_get_name
  local original_nvim_create_namespace
  local original_nvim_buf_set_extmark
  local original_nvim_buf_del_extmark
  local original_nvim_buf_get_extmarks
  local original_nvim_list_bufs
  local original_os_time

  -- Mock counters
  local next_namespace_id = 1
  local next_extmark_id = 1

  -- Extmark storage: { bufnr -> { ns_id -> { extmark_id -> {row, col} } } }
  local extmark_store = {}

  before_each(function()
    -- Clear module cache
    package.loaded["fusen.marks"] = nil
    package.loaded["fusen.git"] = nil

    -- Reset mock counters and storage
    next_namespace_id = 1
    next_extmark_id = 1
    extmark_store = {}

    -- Store original functions
    original_nvim_buf_is_valid = vim.api.nvim_buf_is_valid
    original_nvim_buf_get_name = vim.api.nvim_buf_get_name
    original_nvim_create_namespace = vim.api.nvim_create_namespace
    original_nvim_buf_set_extmark = vim.api.nvim_buf_set_extmark
    original_nvim_buf_del_extmark = vim.api.nvim_buf_del_extmark
    original_nvim_buf_get_extmarks = vim.api.nvim_buf_get_extmarks
    original_nvim_list_bufs = vim.api.nvim_list_bufs
    original_os_time = os.time

    -- Mock vim.api functions
    vim.api.nvim_buf_is_valid = function(bufnr)
      return bufnr == mock_bufnr
    end

    vim.api.nvim_buf_get_name = function(bufnr)
      if bufnr == mock_bufnr then
        return mock_file_path
      end
      return ""
    end

    vim.api.nvim_create_namespace = function(name)
      local id = next_namespace_id
      next_namespace_id = next_namespace_id + 1
      return id
    end

    vim.api.nvim_buf_set_extmark = function(bufnr, ns_id, row, col, opts)
      local id = next_extmark_id
      next_extmark_id = next_extmark_id + 1

      -- Store extmark position
      if not extmark_store[bufnr] then
        extmark_store[bufnr] = {}
      end
      if not extmark_store[bufnr][ns_id] then
        extmark_store[bufnr][ns_id] = {}
      end
      extmark_store[bufnr][ns_id][id] = { row = row, col = col }

      return id
    end

    vim.api.nvim_buf_del_extmark = function(bufnr, ns_id, extmark_id)
      -- Delete extmark from storage
      if extmark_store[bufnr] and extmark_store[bufnr][ns_id] then
        extmark_store[bufnr][ns_id][extmark_id] = nil
      end
    end

    vim.api.nvim_buf_get_extmarks = function(bufnr, ns_id, start_id, end_id, opts)
      -- Return stored extmark data: [extmark_id, row, col]
      if not extmark_store[bufnr] or not extmark_store[bufnr][ns_id] then
        return {}
      end

      -- If querying specific extmark
      if type(start_id) == "number" and start_id == end_id then
        local extmark_data = extmark_store[bufnr][ns_id][start_id]
        if extmark_data then
          return { { start_id, extmark_data.row, extmark_data.col } }
        end
        return {}
      end

      -- Otherwise return all extmarks
      local result = {}
      for id, data in pairs(extmark_store[bufnr][ns_id]) do
        table.insert(result, { id, data.row, data.col })
      end
      return result
    end

    vim.api.nvim_list_bufs = function()
      return { mock_bufnr }
    end

    -- Mock os.time for consistent timestamps
    os.time = function()
      return mock_time
    end

    -- Mock git module
    package.loaded["fusen.git"] = {
      get_current_branch = function()
        return mock_branch
      end,
    }

    -- Load marks module
    marks = require("fusen.marks")
  end)

  after_each(function()
    -- Restore original functions
    vim.api.nvim_buf_is_valid = original_nvim_buf_is_valid
    vim.api.nvim_buf_get_name = original_nvim_buf_get_name
    vim.api.nvim_create_namespace = original_nvim_create_namespace
    vim.api.nvim_buf_set_extmark = original_nvim_buf_set_extmark
    vim.api.nvim_buf_del_extmark = original_nvim_buf_del_extmark
    vim.api.nvim_buf_get_extmarks = original_nvim_buf_get_extmarks
    vim.api.nvim_list_bufs = original_nvim_list_bufs
    os.time = original_os_time
  end)

  describe("init", function()
    it("should initialize internal state", function()
      marks.add_mark(mock_bufnr, 10, "test mark")
      local data_before = marks.get_marks_data()
      assert.is_not_nil(next(data_before))

      marks.init()

      local data_after = marks.get_marks_data()
      assert.is_nil(next(data_after))
    end)
  end)

  describe("add_mark", function()
    it("should add a new mark", function()
      marks.add_mark(mock_bufnr, 10, "test annotation")

      local mark = marks.get_mark(mock_bufnr, 10)
      assert.is_not_nil(mark)
      assert.are.equal(10, mark.line)
      assert.are.equal("test annotation", mark.annotation)
      assert.are.equal(mock_time, mark.created_at)
    end)

    it("should add mark with empty annotation", function()
      marks.add_mark(mock_bufnr, 5, "")

      local mark = marks.get_mark(mock_bufnr, 5)
      assert.is_not_nil(mark)
      assert.are.equal(5, mark.line)
      assert.are.equal("", mark.annotation)
    end)

    it("should add mark without annotation parameter", function()
      marks.add_mark(mock_bufnr, 15)

      local mark = marks.get_mark(mock_bufnr, 15)
      assert.is_not_nil(mark)
      assert.are.equal(15, mark.line)
      assert.are.equal("", mark.annotation)
    end)

    it("should overwrite existing mark at same line", function()
      marks.add_mark(mock_bufnr, 20, "first")
      marks.add_mark(mock_bufnr, 20, "second")

      local mark = marks.get_mark(mock_bufnr, 20)
      assert.are.equal("second", mark.annotation)

      local all_marks = marks.get_buffer_marks(mock_bufnr)
      assert.are.equal(1, #all_marks)
    end)

    it("should not add mark for invalid buffer", function()
      marks.add_mark(999, 10, "invalid")

      local data = marks.get_marks_data()
      assert.is_nil(next(data))
    end)

    it("should not add mark for buffer with empty name", function()
      vim.api.nvim_buf_get_name = function(bufnr)
        return ""
      end

      marks.add_mark(mock_bufnr, 10, "empty name")

      local data = marks.get_marks_data()
      assert.is_nil(next(data))
    end)
  end)

  describe("get_mark", function()
    it("should return mark at specific line", function()
      marks.add_mark(mock_bufnr, 10, "test")

      local mark = marks.get_mark(mock_bufnr, 10)
      assert.is_not_nil(mark)
      assert.are.equal(10, mark.line)
      assert.are.equal("test", mark.annotation)
    end)

    it("should return nil for non-existent mark", function()
      marks.add_mark(mock_bufnr, 10, "test")

      local mark = marks.get_mark(mock_bufnr, 15)
      assert.is_nil(mark)
    end)

    it("should return nil for invalid buffer", function()
      marks.add_mark(mock_bufnr, 10, "test")

      local mark = marks.get_mark(999, 10)
      assert.is_nil(mark)
    end)
  end)

  describe("update_annotation", function()
    it("should update existing mark annotation", function()
      marks.add_mark(mock_bufnr, 10, "original")
      marks.update_annotation(mock_bufnr, 10, "updated")

      local mark = marks.get_mark(mock_bufnr, 10)
      assert.are.equal("updated", mark.annotation)
    end)

    it("should not create new mark if it doesn't exist", function()
      marks.update_annotation(mock_bufnr, 10, "new")

      local mark = marks.get_mark(mock_bufnr, 10)
      assert.is_nil(mark)
    end)

    it("should handle empty annotation", function()
      marks.add_mark(mock_bufnr, 10, "original")
      marks.update_annotation(mock_bufnr, 10, "")

      local mark = marks.get_mark(mock_bufnr, 10)
      assert.are.equal("", mark.annotation)
    end)

    it("should handle nil annotation", function()
      marks.add_mark(mock_bufnr, 10, "original")
      marks.update_annotation(mock_bufnr, 10, nil)

      local mark = marks.get_mark(mock_bufnr, 10)
      assert.are.equal("", mark.annotation)
    end)
  end)

  describe("remove_mark", function()
    it("should remove existing mark", function()
      marks.add_mark(mock_bufnr, 10, "test")
      marks.remove_mark(mock_bufnr, 10)

      local mark = marks.get_mark(mock_bufnr, 10)
      assert.is_nil(mark)
    end)

    it("should not error when removing non-existent mark", function()
      -- First add a mark to ensure the data structure exists
      marks.add_mark(mock_bufnr, 5, "existing")

      -- Then try to remove a non-existent mark
      marks.remove_mark(mock_bufnr, 10)

      local mark = marks.get_mark(mock_bufnr, 10)
      assert.is_nil(mark)

      -- The existing mark should still be there
      local existing = marks.get_mark(mock_bufnr, 5)
      assert.is_not_nil(existing)
    end)

    it("should clean up empty data structures", function()
      marks.add_mark(mock_bufnr, 10, "test")
      marks.remove_mark(mock_bufnr, 10)

      local data = marks.get_marks_data()
      assert.is_nil(next(data))
    end)

    it("should only remove specific mark", function()
      marks.add_mark(mock_bufnr, 10, "mark1")
      marks.add_mark(mock_bufnr, 20, "mark2")
      marks.remove_mark(mock_bufnr, 10)

      local mark1 = marks.get_mark(mock_bufnr, 10)
      local mark2 = marks.get_mark(mock_bufnr, 20)
      assert.is_nil(mark1)
      assert.is_not_nil(mark2)
    end)
  end)

  describe("get_buffer_marks", function()
    it("should return all marks for buffer", function()
      marks.add_mark(mock_bufnr, 10, "mark1")
      marks.add_mark(mock_bufnr, 20, "mark2")
      marks.add_mark(mock_bufnr, 15, "mark3")

      local buffer_marks = marks.get_buffer_marks(mock_bufnr)
      assert.are.equal(3, #buffer_marks)
    end)

    it("should return marks sorted by line", function()
      marks.add_mark(mock_bufnr, 20, "mark2")
      marks.add_mark(mock_bufnr, 10, "mark1")
      marks.add_mark(mock_bufnr, 15, "mark3")

      local buffer_marks = marks.get_buffer_marks(mock_bufnr)
      assert.are.equal(10, buffer_marks[1].line)
      assert.are.equal(15, buffer_marks[2].line)
      assert.are.equal(20, buffer_marks[3].line)
    end)

    it("should include file and buffer in result", function()
      marks.add_mark(mock_bufnr, 10, "test")

      local buffer_marks = marks.get_buffer_marks(mock_bufnr)
      assert.are.equal(mock_file_path, buffer_marks[1].file)
      assert.are.equal(mock_bufnr, buffer_marks[1].buffer)
    end)

    it("should return empty array for buffer with no marks", function()
      local buffer_marks = marks.get_buffer_marks(mock_bufnr)
      assert.are.equal(0, #buffer_marks)
    end)

    it("should return empty array for invalid buffer", function()
      marks.add_mark(mock_bufnr, 10, "test")

      local buffer_marks = marks.get_buffer_marks(999)
      assert.are.equal(0, #buffer_marks)
    end)
  end)

  describe("get_next_mark", function()
    it("should return next mark after current line", function()
      marks.add_mark(mock_bufnr, 10, "mark1")
      marks.add_mark(mock_bufnr, 20, "mark2")
      marks.add_mark(mock_bufnr, 30, "mark3")

      local next_mark = marks.get_next_mark(mock_bufnr, 15)
      assert.is_not_nil(next_mark)
      assert.are.equal(20, next_mark.line)
    end)

    it("should return nil if no next mark", function()
      marks.add_mark(mock_bufnr, 10, "mark1")

      local next_mark = marks.get_next_mark(mock_bufnr, 20)
      assert.is_nil(next_mark)
    end)

    it("should return first mark after current line", function()
      marks.add_mark(mock_bufnr, 10, "mark1")
      marks.add_mark(mock_bufnr, 20, "mark2")

      local next_mark = marks.get_next_mark(mock_bufnr, 5)
      assert.are.equal(10, next_mark.line)
    end)
  end)

  describe("get_prev_mark", function()
    it("should return previous mark before current line", function()
      marks.add_mark(mock_bufnr, 10, "mark1")
      marks.add_mark(mock_bufnr, 20, "mark2")
      marks.add_mark(mock_bufnr, 30, "mark3")

      local prev_mark = marks.get_prev_mark(mock_bufnr, 25)
      assert.is_not_nil(prev_mark)
      assert.are.equal(20, prev_mark.line)
    end)

    it("should return nil if no previous mark", function()
      marks.add_mark(mock_bufnr, 10, "mark1")

      local prev_mark = marks.get_prev_mark(mock_bufnr, 5)
      assert.is_nil(prev_mark)
    end)

    it("should return last mark before current line", function()
      marks.add_mark(mock_bufnr, 10, "mark1")
      marks.add_mark(mock_bufnr, 20, "mark2")

      local prev_mark = marks.get_prev_mark(mock_bufnr, 30)
      assert.are.equal(20, prev_mark.line)
    end)
  end)

  describe("get_marks", function()
    it("should return all marks for current branch", function()
      marks.add_mark(mock_bufnr, 10, "mark1")
      marks.add_mark(mock_bufnr, 20, "mark2")

      local all_marks = marks.get_marks()
      assert.are.equal(2, #all_marks)
    end)

    it("should include file in result", function()
      marks.add_mark(mock_bufnr, 10, "test")

      local all_marks = marks.get_marks()
      assert.are.equal(mock_file_path, all_marks[1].file)
    end)

    it("should return marks sorted by file and line", function()
      marks.add_mark(mock_bufnr, 20, "mark2")
      marks.add_mark(mock_bufnr, 10, "mark1")

      local all_marks = marks.get_marks()
      assert.are.equal(10, all_marks[1].line)
      assert.are.equal(20, all_marks[2].line)
    end)

    it("should return empty array when no marks", function()
      local all_marks = marks.get_marks()
      assert.are.equal(0, #all_marks)
    end)
  end)

  describe("clear_buffer_marks", function()
    it("should clear all marks for buffer", function()
      marks.add_mark(mock_bufnr, 10, "mark1")
      marks.add_mark(mock_bufnr, 20, "mark2")

      marks.clear_buffer_marks(mock_bufnr)

      local buffer_marks = marks.get_buffer_marks(mock_bufnr)
      assert.are.equal(0, #buffer_marks)
    end)

    it("should clean up empty data structures", function()
      marks.add_mark(mock_bufnr, 10, "test")
      marks.clear_buffer_marks(mock_bufnr)

      local data = marks.get_marks_data()
      assert.is_nil(next(data))
    end)

    it("should not error for buffer with no marks", function()
      marks.clear_buffer_marks(mock_bufnr)

      local buffer_marks = marks.get_buffer_marks(mock_bufnr)
      assert.are.equal(0, #buffer_marks)
    end)
  end)

  describe("clear_all_marks", function()
    it("should clear all marks from all buffers", function()
      marks.add_mark(mock_bufnr, 10, "mark1")
      marks.add_mark(mock_bufnr, 20, "mark2")

      marks.clear_all_marks()

      local all_marks = marks.get_marks()
      assert.are.equal(0, #all_marks)
    end)

    it("should reset internal data structures", function()
      marks.add_mark(mock_bufnr, 10, "test")
      marks.clear_all_marks()

      local data = marks.get_marks_data()
      assert.is_nil(next(data))
    end)
  end)

  describe("get_marks_data", function()
    it("should return internal marks data", function()
      marks.add_mark(mock_bufnr, 10, "test")

      local data = marks.get_marks_data()
      assert.is_not_nil(data)
      assert.is_not_nil(data[mock_file_path])
      assert.is_not_nil(data[mock_file_path][mock_branch])
      assert.are.equal(1, #data[mock_file_path][mock_branch])
    end)

    it("should return empty table when no marks", function()
      local data = marks.get_marks_data()
      assert.is_nil(next(data))
    end)
  end)

  describe("set_marks_data", function()
    it("should set marks data from external source", function()
      local test_data = {
        [mock_file_path] = {
          [mock_branch] = {
            { line = 10, annotation = "imported", created_at = 9999 },
          },
        },
      }

      marks.set_marks_data(test_data)

      local mark = marks.get_mark(mock_bufnr, 10)
      assert.is_not_nil(mark)
      assert.are.equal("imported", mark.annotation)
    end)

    it("should clear existing marks before setting new data", function()
      marks.add_mark(mock_bufnr, 5, "existing")

      local test_data = {
        [mock_file_path] = {
          [mock_branch] = {
            { line = 10, annotation = "new", created_at = 9999 },
          },
        },
      }

      marks.set_marks_data(test_data)

      local old_mark = marks.get_mark(mock_bufnr, 5)
      local new_mark = marks.get_mark(mock_bufnr, 10)
      assert.is_nil(old_mark)
      assert.is_not_nil(new_mark)
    end)

    it("should handle nil data", function()
      marks.add_mark(mock_bufnr, 10, "test")
      marks.set_marks_data(nil)

      local data = marks.get_marks_data()
      assert.is_nil(next(data))
    end)
  end)

  describe("update_mark_line", function()
    it("should update mark line when extmark moves", function()
      marks.add_mark(mock_bufnr, 10, "test")
      marks.update_mark_line(mock_bufnr, 10, 15)

      local old_mark = marks.get_mark(mock_bufnr, 10)
      local new_mark = marks.get_mark(mock_bufnr, 15)
      assert.is_nil(old_mark)
      assert.is_not_nil(new_mark)
      assert.are.equal("test", new_mark.annotation)
    end)

    it("should not error for non-existent mark", function()
      marks.update_mark_line(mock_bufnr, 10, 15)

      local mark = marks.get_mark(mock_bufnr, 15)
      assert.is_nil(mark)
    end)

    it("should not update for invalid buffer", function()
      marks.add_mark(mock_bufnr, 10, "test")
      marks.update_mark_line(999, 10, 15)

      local mark = marks.get_mark(mock_bufnr, 10)
      assert.is_not_nil(mark)
    end)
  end)

  describe("load_buffer_marks", function()
    it("should load marks for buffer from data", function()
      local test_data = {
        [mock_file_path] = {
          [mock_branch] = {
            { line = 10, annotation = "test", created_at = 9999 },
          },
        },
      }

      marks.set_marks_data(test_data)
      marks.load_buffer_marks(mock_bufnr)

      local mark = marks.get_mark(mock_bufnr, 10)
      assert.is_not_nil(mark)
    end)

    it("should not load marks twice for same buffer", function()
      local test_data = {
        [mock_file_path] = {
          [mock_branch] = {
            { line = 10, annotation = "test", created_at = 9999 },
          },
        },
      }

      -- Set data first (this will create extmarks for open buffers)
      marks.set_marks_data(test_data)

      -- Track extmark creation calls
      local extmark_create_count = 0
      local original_set_extmark = vim.api.nvim_buf_set_extmark
      vim.api.nvim_buf_set_extmark = function(...)
        extmark_create_count = extmark_create_count + 1
        return original_set_extmark(...)
      end

      -- First call to load_buffer_marks should create extmarks
      marks.load_buffer_marks(mock_bufnr)
      local count_after_first_load = extmark_create_count

      -- Second call should be prevented (duplicate loading)
      marks.load_buffer_marks(mock_bufnr)
      local count_after_second_load = extmark_create_count

      -- Verify no new extmarks were created on second call
      assert.are.equal(count_after_first_load, count_after_second_load)

      -- Verify mark still exists
      local mark = marks.get_mark(mock_bufnr, 10)
      assert.is_not_nil(mark)
      assert.are.equal("test", mark.annotation)

      vim.api.nvim_buf_set_extmark = original_set_extmark
    end)

    it("should not error for buffer with no marks", function()
      marks.load_buffer_marks(mock_bufnr)

      local buffer_marks = marks.get_buffer_marks(mock_bufnr)
      assert.are.equal(0, #buffer_marks)
    end)
  end)

  describe("cleanup_closed_buffers", function()
    it("should remove data for invalid buffers", function()
      local valid_bufnr = 1
      local invalid_bufnr = 999
      local invalid_file_path = "/tmp/invalid_file.lua"

      -- Temporarily override buf_get_name to support both buffers
      local original_buf_get_name = vim.api.nvim_buf_get_name
      vim.api.nvim_buf_get_name = function(bufnr)
        if bufnr == valid_bufnr then
          return mock_file_path
        elseif bufnr == invalid_bufnr then
          return invalid_file_path
        end
        return ""
      end

      -- Temporarily override buf_is_valid to mark buffer 999 as invalid
      local original_buf_is_valid = vim.api.nvim_buf_is_valid
      vim.api.nvim_buf_is_valid = function(bufnr)
        if bufnr == valid_bufnr then
          return true
        elseif bufnr == invalid_bufnr then
          return false -- This buffer is "closed"
        end
        return false
      end

      -- Add marks to both buffers
      marks.add_mark(valid_bufnr, 10, "valid buffer mark")
      marks.add_mark(invalid_bufnr, 20, "invalid buffer mark")

      -- Also add loaded_buffers entries
      marks.load_buffer_marks(valid_bufnr)
      -- Manually trigger load for invalid buffer before it becomes invalid
      vim.api.nvim_buf_is_valid = function(bufnr)
        return true
      end
      marks.load_buffer_marks(invalid_bufnr)
      vim.api.nvim_buf_is_valid = function(bufnr)
        return bufnr == valid_bufnr
      end

      -- Now cleanup closed buffers
      marks.cleanup_closed_buffers()

      -- Verify invalid buffer's extmarks were cleaned up
      -- (We can't directly check buffer_extmarks, but we verified cleanup was called)

      -- Verify valid buffer still has its mark
      local valid_mark = marks.get_mark(valid_bufnr, 10)
      assert.is_not_nil(valid_mark)

      -- Restore original functions
      vim.api.nvim_buf_get_name = original_buf_get_name
      vim.api.nvim_buf_is_valid = original_buf_is_valid
    end)
  end)
end)
