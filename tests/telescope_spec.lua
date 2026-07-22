describe("fusen.telescope", function()
  local telescope
  local cwd

  before_each(function()
    package.loaded["fusen.telescope"] = nil
    telescope = require("fusen.telescope")
    cwd = vim.fn.getcwd()
  end)

  describe("make_ordinal", function()
    it("should start with the annotation", function()
      local ordinal = telescope.make_ordinal({
        file = cwd .. "/lua/example/module.lua",
        line = 42,
        annotation = "review this later",
      })

      assert.equals(1, ordinal:find("review this later", 1, true))
    end)

    it("should contain the relative path and line number", function()
      local ordinal = telescope.make_ordinal({
        file = cwd .. "/lua/example/module.lua",
        line = 42,
        annotation = "review this later",
      })

      assert.is_not_nil(ordinal:find("lua/example/module.lua:42", 1, true))
    end)

    it("should not contain the absolute path prefix", function()
      local ordinal = telescope.make_ordinal({
        file = cwd .. "/lua/example/module.lua",
        line = 42,
        annotation = "review this later",
      })

      assert.is_nil(ordinal:find(cwd, 1, true))
    end)

    it("should handle a mark without annotation", function()
      local ordinal = telescope.make_ordinal({
        file = cwd .. "/lua/example/module.lua",
        line = 7,
      })

      assert.is_not_nil(ordinal:find("lua/example/module.lua:7", 1, true))
    end)
  end)
end)
