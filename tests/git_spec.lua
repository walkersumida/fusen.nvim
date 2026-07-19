describe("fusen.git", function()
  local git

  before_each(function()
    package.loaded["fusen.git"] = nil
    git = require("fusen.git")
  end)

  describe("setup_autocmds", function()
    it("should register a DirChanged autocmd to invalidate the branch cache", function()
      git.setup_autocmds()

      local autocmds = vim.api.nvim_get_autocmds({ group = "FusenGit", event = "DirChanged" })
      assert.are.equal(1, #autocmds)
    end)

    it("should register a BufEnter autocmd", function()
      git.setup_autocmds()

      local autocmds = vim.api.nvim_get_autocmds({ group = "FusenGit", event = "BufEnter" })
      assert.are.equal(1, #autocmds)
    end)
  end)
end)
