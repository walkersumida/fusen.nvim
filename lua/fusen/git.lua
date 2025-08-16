local M = {}

local function execute_command(cmd)
  local handle = io.popen(cmd .. " 2>/dev/null")
  if not handle then
    return nil
  end
  local result = handle:read("*a")
  handle:close()
  if result then
    result = result:gsub("^%s+", ""):gsub("%s+$", "")
  end
  return result ~= "" and result or nil
end

function M.get_git_root(path)
  path = path or vim.fn.getcwd()
  local cmd = string.format("cd %s && git rev-parse --show-toplevel", vim.fn.shellescape(path))
  return execute_command(cmd)
end

function M.get_current_branch(path)
  path = path or vim.fn.getcwd()
  local cmd = string.format("cd %s && git branch --show-current", vim.fn.shellescape(path))
  local branch = execute_command(cmd)

  if not branch or branch == "" then
    cmd = string.format("cd %s && git rev-parse --abbrev-ref HEAD", vim.fn.shellescape(path))
    branch = execute_command(cmd)
  end

  return branch
end

function M.is_git_repo(path)
  path = path or vim.fn.getcwd()
  local cmd = string.format("cd %s && git rev-parse --is-inside-work-tree", vim.fn.shellescape(path))
  local result = execute_command(cmd)
  return result == "true"
end

function M.get_relative_path(file_path, git_root)
  if not git_root then
    return file_path
  end

  file_path = vim.fn.fnamemodify(file_path, ":p")
  git_root = vim.fn.fnamemodify(git_root, ":p")

  if vim.startswith(file_path, git_root) then
    return file_path:sub(#git_root + 1):gsub("^/", "")
  end

  return file_path
end

local branch_cache = {
  branch = nil,
  git_root = nil,
  last_check = 0,
}

function M.get_branch_info(path)
  path = path or vim.fn.getcwd()
  local now = vim.loop.now()

  if branch_cache.last_check and (now - branch_cache.last_check) < 1000 then
    return branch_cache.branch, branch_cache.git_root
  end

  if not M.is_git_repo(path) then
    branch_cache.branch = nil
    branch_cache.git_root = nil
    branch_cache.last_check = now
    return nil, nil
  end

  local git_root = M.get_git_root(path)
  local branch = M.get_current_branch(path)

  branch_cache.branch = branch
  branch_cache.git_root = git_root
  branch_cache.last_check = now

  return branch, git_root
end

function M.setup_autocmds()
  local group = vim.api.nvim_create_augroup("FusenGit", { clear = true })

  vim.api.nvim_create_autocmd({ "BufEnter", "FocusGained" }, {
    group = group,
    callback = function()
      branch_cache.last_check = 0

      local fusen = require("fusen")
      if fusen.refresh_marks then
        fusen.refresh_marks()
      end
    end,
  })

  vim.api.nvim_create_autocmd("User", {
    pattern = "FugitiveChanged",
    group = group,
    callback = function()
      branch_cache.last_check = 0

      local fusen = require("fusen")
      if fusen.refresh_marks then
        fusen.refresh_marks()
      end
    end,
  })
end

return M
