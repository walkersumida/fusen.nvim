-- Telescope extension for fusen.nvim
local has_telescope, telescope = pcall(require, "telescope")

if not has_telescope then
  return {}
end

local fusen_telescope = require("fusen.telescope")

return telescope.register_extension({
  setup = function(ext_config, config)
    -- Extension setup
  end,
  exports = {
    marks = fusen_telescope.marks_picker,
    fusen = fusen_telescope.marks_picker,
  },
})

