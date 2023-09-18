local set = vim.opt
local api = vim.api
local fn = vim.fn
local cmd = api.nvim_command
local utils = require("ricdotline.utils")

local Sl = {}
local Config = {}

function Sl.setup(opts)
  local ok, job = pcall(require, "plenary.job")
  if not ok then
    return print("You need plenary installed to use ricdotline")
  end

  if (opts ~= nil) then
    Config = opts
  end

  local chars = {
    blank = " ",
    arrow = { left = "", right = "" },
    round = { left = "", right = "" },
    thin = { left = "", right = "" },
    tilt = { left = "", right = "" },
    upstream = "  ",
    directory = "  ",
    watch = " ",
    config = "  ",
    unsaved = "  ",
    git = {
      added = "  ",
      changed = "  ",
      removed = "  ",
    },
    diagnostics = {
      error = " ",
      warn = " ",
      hint = " ",
      info = " ",
    }
  }

  local function getIcon(filename, filetype)
    local icon = ""

    local devicons_ok, devicons = pcall(require, "nvim-web-devicons")

    if not devicons_ok then
      return icon
    end

    local ft_icon = devicons.get_icon(filename, filetype)
    icon = ft_icon or ""

    return icon
  end

  local function getMode()
    local mode = api.nvim_get_mode().mode

    local modes = {
      v = "VISUAL",
      n = "NORMAL",
      i = "INSERT",
      c = "COMMAND",
      t = "TERMINAL",
      R = "REPLACE MULTI",
    }

    return modes[mode] or mode
  end

  local function getFile()
    local filename = fn.expand "%:t"
    local icon = getIcon("default_icon")

    if filename == nil or filename == "" then
      return icon .. " "
    end

    return getIcon(filename) .. " " .. filename
  end

  local function getProjectDir()
    local projectDir = fn.fnamemodify(fn.getcwd(), ":t")

    return getIcon("default_icon") .. " /" .. projectDir
  end

  local function getGitBranch()
    if not vim.g.gitsigns_head then
      return ""
    end

    --return getIcon("github") .. chars["blank"] .. chars["upstream"] .. vim.b.gitsigns_head
    return chars["upstream"] .. vim.g.gitsigns_head
  end

  local function getGitStats()
    if utils.getPaneWidth() < 120 then
      return ""
    end

    if not vim.b.gitsigns_head or not vim.g.gitsigns_head then
      return ""
    end

    local git = vim.b.gitsigns_status_dict

    local added = (git.added and git.added ~= 0) and (chars["git"]["added"] .. git.added .. " ") or ""
    local changed = (git.changed and git.changed ~= 0) and (chars["git"]["changed"] .. git.changed .. " ") or ""
    local removed = (git.removed and git.removed ~= 0) and (chars["git"]["removed"] .. git.removed .. " ") or ""

    if added == "" and changed == "" and removed == "" then
      return ""
    end

    return added .. changed .. removed .. chars["blank"]
  end

  local function getCurrentLsp()
    if (utils.getPaneWidth() < 120) then
      return ""
    end

    local lsps = vim.lsp.get_active_clients()
    local lsp = ""

    if not lsps or lsps == nil then
      return lsp
    end

    for _, client in pairs(lsps) do
      if client.attached_buffers[api.nvim_get_current_buf()] and client.name ~= "null-ls" then
        lsp = "   LSP ~ " .. client.name
      end
    end

    return lsp
  end

  local function getLineAndCol()
    local current_line = fn.line "."
    local current_col = fn.col "."
    local total_lines = fn.line "$"

    local perc = math.modf((current_line * 100) / total_lines)
    local text = "%%" .. perc

    text = (current_line == 1 and "Top") or text
    text = (current_line == total_lines and "Bot") or text

    return current_line .. ":" .. current_col .. " - " .. text
  end

  local getWakaTimeStats = function() return "" end
  if Config.wakatime == true then
    -- TODO: refactor using timers from luv
    local startTime = os.time()
    local wakatime = ""

    local function runWTJob()
      job:new({
        command = "wakatime-cli",
        args = { "--today" },
        on_exit = function(j, _)
          wakatime = j:result()[1] or ""
        end,
      }):start()
      startTime = os.time()
    end
    runWTJob() -- run once on start

    getWakaTimeStats = function()
      if utils.getPaneWidth() < 120 then
        return ""
      end

      -- every 5 minutes
      if os.time() - startTime >= (60 * 5) then
        runWTJob()
        startTime = os.time()
      end

      if wakatime == "" then return wakatime end

      return chars["watch"] .. chars["blank"] .. wakatime .. chars["blank"]
    end
  end

  local function getBufDiagnostics()
    if api.nvim_buf_get_name(0) == "" or api.nvim_buf_get_name(0) == nil then return "" end

    if (utils.getPaneWidth() < 120) then
      return ""
    end

    local errors = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.ERROR })
    local warns = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.WARN })
    local hints = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.HINT })
    local info = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.INFO })

    errors = (errors and errors > 0) and ("%#LspE#" .. chars["diagnostics"]["error"] .. errors .. chars["blank"]) or ""
    warns = (warns and warns > 0) and ("%#LspW#" .. chars["diagnostics"]["warn"] .. warns .. chars["blank"]) or ""
    hints = (hints and hints > 0) and ("%#LspH#" .. chars["diagnostics"]["hint"] .. hints .. chars["blank"]) or ""
    info = (info and info > 0) and ("%#LspI#" .. chars["diagnostics"]["info"] .. info .. chars["blank"]) or ""

    local diagnostics = errors .. warns .. hints .. info

    if (diagnostics ~= "") then
      return chars["blank"] .. diagnostics .. chars["blank"]
    else
      return ""
    end
  end

  local function getIsUnsaved()
    local buf = api.nvim_get_current_buf()
    local unsaved = api.nvim_buf_get_option(buf, 'modified')

    return (unsaved and chars["unsaved"]) or ""
  end

  -- LINE BUILDER --
  local separator = Config.separator or "arrow"
  local colorScheme = Config.theme or vim.g.colors_name
  local colors = require("ricdotline.colors")[colorScheme]

  if Config.colors then
    for k, v in pairs(Config.colors) do
      colors[k] = v
    end
  end

  cmd("hi Reset guibg=" .. colors["reset"]["bg"] .. " gui=bold")
  cmd("hi SepA guibg=" .. colors["sep"]["a"]["bg"] .. " guifg=" .. colors["sep"]["a"]["fg"])
  cmd("hi SepB guibg=" .. colors["sep"]["b"]["bg"] .. " guifg=" .. colors["sep"]["b"]["fg"])
  cmd("hi SepC guibg=" .. colors["sep"]["c"]["bg"] .. " guifg=" .. colors["sep"]["c"]["fg"])
  cmd("hi SepD guibg=" .. colors["sep"]["d"]["bg"] .. " guifg=" .. colors["sep"]["d"]["fg"])
  cmd("hi SepE guibg=" .. colors["sep"]["e"]["bg"] .. " guifg=" .. colors["sep"]["e"]["fg"])

  cmd("hi LspE guibg=" .. colors["diagnostic"]["bg"] .. " guifg=" .. colors["diagnostic"]["error"])
  cmd("hi LspW guibg=" .. colors["diagnostic"]["bg"] .. " guifg=" .. colors["diagnostic"]["warn"])
  cmd("hi LspH guibg=" .. colors["diagnostic"]["bg"] .. " guifg=" .. colors["diagnostic"]["hint"])
  cmd("hi LspI guibg=" .. colors["diagnostic"]["bg"] .. " guifg=" .. colors["diagnostic"]["info"])

  -- parts
  cmd("hi PartA guibg=" .. colors["a"]["bg"] .. " guifg=" .. colors["a"]["fg"])
  cmd("hi PartB guibg=" .. colors["b"]["bg"] .. " guifg=" .. colors["b"]["fg"])
  cmd("hi PartC guibg=" .. colors["c"]["bg"] .. " guifg=" .. colors["c"]["fg"])
  cmd("hi PartD guibg=" .. colors["d"]["bg"] .. " guifg=" .. colors["d"]["fg"])
  cmd("hi PartE guibg=" .. colors["e"]["bg"] .. " guifg=" .. colors["e"]["fg"])
  cmd("hi PartF guibg=" .. colors["f"]["bg"] .. " guifg=" .. colors["f"]["fg"])
  cmd("hi PartG guibg=" .. colors["g"]["bg"] .. " guifg=" .. colors["g"]["fg"])
  cmd("hi PartH guibg=" .. colors["h"]["bg"] .. " guifg=" .. colors["h"]["fg"])
  cmd("hi PartI guibg=" .. colors["i"]["bg"] .. " guifg=" .. colors["i"]["fg"])
  cmd("hi Inactive guibg=" .. colors["inactive"]["bg"] .. " guifg=" .. colors["inactive"]["fg"])

  local function line_part(part, default_fn)
    if (Config[part] == nil) then return default_fn() end
    if (type(Config[part]) == "string") then return Config[part] end

    local part_result = ""
    if (type(Config[part]) == "function") then part_result = Config[part]() end

    if (type(part_result) ~= "string") then
      print(part .. " needs to be of type string or a function that return a string")
      return ""
    end

    return part_result
  end

  function Active()
    set.laststatus = 2

    local statusline = {
      "%#PartA#" .. chars["blank"] .. line_part("partA", getMode) .. chars["blank"],
      "%#SepA#" .. chars[separator]["right"],
      "%#PartB#" .. chars["blank"] .. line_part("partB", getFile) .. chars["blank"],
      "%#SepB#" .. chars[separator]["right"],
      "%#PartC#" .. chars["blank"] .. line_part("partC", getGitBranch) .. chars["blank"],
      "%#SepC#" .. chars["thin"]["right"],
      "%#PartD#" .. chars["blank"] .. line_part("partD", getGitStats),
      "%#SepC#" .. chars["thin"]["right"],
      "%#PartE#" .. chars["blank"] .. line_part("partE", getIsUnsaved),

      -- right side
      "%=",

      getWakaTimeStats(),
      "%#SepC#" .. chars["thin"]["left"],
      "%#PartF#" .. chars["blank"] .. line_part("partF", getBufDiagnostics),
      "%#SepC#" .. chars["thin"]["left"],
      "%#PartG#" .. chars["blank"] .. line_part("partG", getCurrentLsp) .. chars["blank"],
      "%#SepD#" .. chars[separator]["left"],
      "%#PartH#" .. chars["blank"] .. line_part("partH", getProjectDir) .. chars["blank"],
      "%#SepE#" .. chars[separator]["left"],
      "%#PartI#" .. chars["blank"] .. line_part("partI", getLineAndCol) .. chars["blank"],
    }

    return table.concat(statusline)
  end

  function Inactive()
    set.laststatus = 2

    local statusline = {
      "%#Inactive#",
      chars["blank"] .. getFile() .. chars["blank"],
      chars["thin"]["right"] .. chars["blank"],
      getGitStats() .. chars["blank"],
      chars["thin"]["right"],
      getIsUnsaved(),
      "%=",
      chars["blank"] .. chars["thin"]["left"] .. chars["blank"],
      getProjectDir() .. chars["blank"],
    }

    return table.concat(statusline)
  end

  vim.api.nvim_exec([[
    augroup Statusline
      autocmd!
      autocmd VimEnter,WinEnter,BufEnter * setlocal statusline=%!v:lua.Active()
      autocmd WinLeave,BufLeave * setlocal statusline=%{%v:lua.Inactive()%}
    augroup END
  ]], false)
end

return Sl
