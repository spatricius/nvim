-- Set <space> as the leader key
-- See `:help mapleader`
--  NOTE: Must happen before plugins are loaded (otherwise wrong leader will be used)
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Set to true if you have a Nerd Font installed and selected in the terminal
vim.g.have_nerd_font = true
vim.opt.guifont = 'SauceCodePro Nerd Font Mono:h12'

-- Disable netrw in favor of Neo-tree
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Make line numbers default
vim.o.number = true
vim.o.relativenumber = true

-- Enable mouse mode, can be useful for resizing splits for example!
vim.o.mouse = 'a'

-- Don't show the mode, since it's already in the status line
vim.o.showmode = false

-- Sync clipboard between OS and Neovim.
--  Schedule the setting after `UiEnter` because it can increase startup-time.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
vim.schedule(function() vim.o.clipboard = 'unnamedplus' end)

-- Enable break indent
vim.o.breakindent = true

-- Enable undo/redo changes even after closing and reopening a file
vim.o.undofile = true

-- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
vim.o.ignorecase = true
vim.o.smartcase = true

-- Keep signcolumn on by default
vim.o.signcolumn = 'yes'

-- Decrease update time
vim.o.updatetime = 250

-- Decrease mapped sequence wait time
vim.o.timeoutlen = 300

-- Configure how new splits should be opened
vim.o.splitright = true
vim.o.splitbelow = true

-- Sets how neovim will display certain whitespace characters in the editor.
vim.o.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- Preview substitutions live, as you type!
vim.o.inccommand = 'split'

-- Show which line your cursor is on
vim.o.cursorline = true

-- Minimal number of screen lines to keep above and below the cursor.
vim.o.scrolloff = 10

-- if performing an operation that would fail due to unsaved changes in the buffer (like `:q`),
-- instead raise a dialog asking if you wish to save the current file(s)
-- See `:help 'confirm'`
vim.o.confirm = true

-- Keep sessions from restoring a stale global cwd. Project-root switching below
-- will set cwd from the active file instead.
vim.o.sessionoptions = 'blank,folds,help,tabpages,winsize,winpos,terminal'

-- Clear highlights on search when pressing <Esc> in normal mode
--  See `:help hlsearch`
vim.diagnostic.config {
  update_in_insert = false,
  severity_sort = true,
  signs = { severity = { min = vim.diagnostic.severity.ERROR } },
  float = { border = 'rounded', source = 'if_many' },
  underline = { severity = { min = vim.diagnostic.severity.ERROR } },

  -- Can switch between these as you prefer
  virtual_text = { severity = { min = vim.diagnostic.severity.ERROR } }, -- Text shows up at the end of the line
  virtual_lines = false, -- Text shows up underneath the line, with virtual lines

  -- Auto open the float, so you can easily read the errors when jumping with `[d` and `]d`
  jump = {
    on_jump = function() vim.diagnostic.open_float(nil, { scope = 'line' }) end,
  },
}

require('keymaps').setup()
require('keymaps').setup_debug_keymaps()

-- [[ Basic Autocommands ]]
--  See `:help lua-guide-autocommands`

-- Highlight when yanking (copying) text
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('highlight-yank', { clear = true }),
  callback = function() vim.hl.on_yank() end,
})

local function autosave_buffer(args)
  local buf = args.buf
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return end
  if not vim.bo[buf].modifiable or vim.bo[buf].readonly then return end
  if vim.bo[buf].buftype ~= '' then return end
  if vim.api.nvim_buf_get_name(buf) == '' then return end
  if not vim.bo[buf].modified then return end

  vim.cmd('silent! write')
end

vim.api.nvim_create_autocmd({ 'FocusLost', 'BufLeave' }, {
  desc = 'Autosave modified file buffers',
  group = vim.api.nvim_create_augroup('config-autosave', { clear = true }),
  callback = autosave_buffer,
})

local helpers = require 'helpers'

local function set_project_cwd(args)
  local buf = args.buf
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return end
  if vim.bo[buf].buftype ~= '' then return end

  local name = vim.api.nvim_buf_get_name(buf)
  if name == '' then return end

  local root = helpers.project_root(name)
  if root == vim.fn.getcwd() then return end

  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_get_current_buf() == buf then
      vim.cmd.cd(vim.fn.fnameescape(root))
    end
  end)
end

vim.api.nvim_create_autocmd({ 'BufEnter', 'VimEnter' }, {
  desc = 'Update cwd to current buffer project root',
  group = vim.api.nvim_create_augroup('config-project-cwd', { clear = true }),
  callback = set_project_cwd,
})


-- [[ Install `lazy.nvim` plugin manager ]]
--    See `:help lazy.nvim.txt` or https://github.com/folke/lazy.nvim for more info
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  local out = vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath }
  if vim.v.shell_error ~= 0 then error('Error cloning lazy.nvim:' .. out) end
end

---@type vim.Option
local rtp = vim.opt.rtp
rtp:prepend(lazypath)

-- [[ Configure and install plugins ]]
require 'plugins'

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et
