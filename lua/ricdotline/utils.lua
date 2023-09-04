local U = {}
local api = vim.api

function U.getPaneWidth()
  local total_width = api.nvim_win_get_width(0)
  return total_width
end

return U
