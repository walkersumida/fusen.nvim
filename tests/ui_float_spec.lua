describe("fusen.ui float window", function()
  local buf_counter = 0

  local function find_float_win()
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      local cfg = vim.api.nvim_win_get_config(win)
      if cfg.relative ~= "" then
        return win
      end
    end
    return nil
  end

  local function longest_display_width(annotation)
    local longest = 1
    for _, line in ipairs(vim.split(annotation, "\n", { plain = true })) do
      local w = vim.fn.strdisplaywidth(line)
      if w > longest then
        longest = w
      end
    end
    return longest
  end

  -- Trigger the float via the public entry point by stubbing the mark lookup
  local function show_float(annotation)
    package.loaded["fusen.marks"] = {
      get_mark = function()
        return { line = 1, annotation = annotation, created_at = 0 }
      end,
    }
    require("fusen.ui").check_cursor_float()
    return find_float_win()
  end

  -- Assert the float exactly fits what Neovim renders (clamped), i.e. no text is cut off
  local function assert_float_fits(annotation)
    local win = show_float(annotation)
    assert.is_not_nil(win)

    local float_config = require("fusen.config").get().annotation_display.float
    local max_width = float_config.max_width or 50
    local max_height = float_config.max_height or 10

    local expected_width = math.min(max_width, math.max(1, longest_display_width(annotation)))
    assert.are.equal(expected_width, vim.api.nvim_win_get_width(win))

    local needed = vim.api.nvim_win_text_height(win, {}).all
    local expected_height = math.min(max_height, math.max(1, needed))
    assert.are.equal(expected_height, vim.api.nvim_win_get_height(win))

    return win, needed
  end

  before_each(function()
    require("fusen.config").setup({})

    -- check_cursor_float ignores unnamed buffers; unique names avoid E95
    buf_counter = buf_counter + 1
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, "/tmp/fusen_ui_float_spec_" .. buf_counter .. ".txt")
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
  end)

  after_each(function()
    -- Close the float via the nil-mark path to reset module-local state
    package.loaded["fusen.marks"] = {
      get_mark = function()
        return nil
      end,
    }
    require("fusen.ui").check_cursor_float()
    package.loaded["fusen.marks"] = nil
  end)

  -- Wrapping patterns that must never be cut off; the regression case
  -- reproduced the original bug (estimated 2 rows vs 3 actually rendered)
  local cases = {
    {
      name = "mixed Japanese and English text (regression)",
      annotation = "この sample の注釈 wrap するということは、その行数 screen row が消費される？",
    },
    {
      name = "long English text with spaces",
      annotation = "this is a fairly long English annotation that needs to wrap across several rows in the float window",
    },
    {
      name = "long English word without spaces",
      annotation = string.rep("a", 120),
    },
    {
      name = "long Japanese text without spaces",
      annotation = "これはスペースを含まない長い日本語のテキストで折り返しの検証をするためのものです",
    },
    {
      name = "Japanese text with punctuation",
      annotation = "これは句読点を含むテキストです。折り返し位置は、禁則処理の影響を受けますか？たぶん受けます。",
    },
    {
      name = "double-width char straddling the wrap boundary",
      annotation = "a" .. string.rep("あ", 60),
    },
    {
      name = "multi-line annotation",
      annotation = "1行目\n2行目はとても長いテキストで、floating window の幅を超えて折り返されることを想定しています",
    },
    {
      name = "annotation containing empty lines",
      annotation = "上\n\n下",
    },
  }

  for _, case in ipairs(cases) do
    it("fits " .. case.name, function()
      assert_float_fits(case.annotation)
    end)
  end

  it("shows a single-row float for a short one-line note", function()
    local win = assert_float_fits("short note")
    assert.are.equal(vim.fn.strdisplaywidth("short note"), vim.api.nvim_win_get_width(win))
    assert.are.equal(1, vim.api.nvim_win_get_height(win))
  end)

  it("clamps height to max_height for very long annotations", function()
    local win, needed = assert_float_fits(string.rep("長い注釈テキスト ", 60))
    local max_height = require("fusen.config").get().annotation_display.float.max_height
    assert.is_true(needed > max_height)
    assert.are.equal(max_height, vim.api.nvim_win_get_height(win))
  end)

  it("respects custom max_width and max_height", function()
    require("fusen.config").setup({
      annotation_display = {
        float = { max_width = 30, max_height = 5 },
      },
    })

    local win = assert_float_fits(string.rep("カスタム設定の検証テキスト ", 20))
    assert.are.equal(30, vim.api.nvim_win_get_width(win))
    assert.are.equal(5, vim.api.nvim_win_get_height(win))
  end)

  it("accounts for breakindent when enabled", function()
    require("fusen.config").setup({
      annotation_display = {
        float = { breakindent = true },
      },
    })

    -- Leading indent shrinks the effective width of wrapped rows
    local win = assert_float_fits("        indented annotation that is long enough to wrap onto multiple rows here")
    assert.is_true(vim.api.nvim_win_get_option(win, "breakindent"))
  end)
end)
