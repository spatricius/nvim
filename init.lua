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
vim.o.sessionoptions = 'blank,buffers,folds,help,tabpages,winsize,winpos,terminal,localoptions'

-- Clear highlights on search when pressing <Esc> in normal mode
--  See `:help hlsearch`
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Use <C-S-V> to paste clipboard anywhere
vim.keymap.set({ 'i', 'c', 'n' }, '<C-S-V>', '<C-r>+')

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
  jump = { float = true },
}

vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
-- is not what someone will guess without a bit more experience.
--
-- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
-- or just use <C-\><C-n> to exit terminal mode
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- Keybinds to make split navigation easier.
--  Use CTRL+<hjkl> to switch between windows
vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

-- NOTE: Some terminals have colliding keymaps or are not able to send distinct keycodes
vim.keymap.set('n', '<C-S-h>', '<C-w>H', { desc = 'Move window to the left' })
vim.keymap.set('n', '<C-S-l>', '<C-w>L', { desc = 'Move window to the right' })
vim.keymap.set('n', '<C-S-j>', '<C-w>J', { desc = 'Move window to the lower' })
vim.keymap.set('n', '<C-S-k>', '<C-w>K', { desc = 'Move window to the upper' })

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
  group = vim.api.nvim_create_augroup('kickstart-autosave', { clear = true }),
  callback = autosave_buffer,
})

local project_root_markers = {
  '.git',
  'composer.json',
}

local function editorconfig_has_root(dir)
  local path = vim.fs.joinpath(dir, '.editorconfig')
  if vim.uv.fs_stat(path) == nil then return false end

  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then return false end

  for _, line in ipairs(lines) do
    if line:gsub('%s+', ''):lower() == 'root=true' then
      return true
    end
  end

  return false
end

local function is_project_root(dir)
  for _, marker in ipairs(project_root_markers) do
    if vim.uv.fs_stat(vim.fs.joinpath(dir, marker)) ~= nil then
      return true
    end
  end

  return editorconfig_has_root(dir)
end

local function project_root(path)
  if type(path) == 'number' then
    path = vim.api.nvim_buf_get_name(path)
  end

  if path == nil or path == '' then
    return vim.fn.getcwd()
  end

  local stat = vim.uv.fs_stat(path)
  local dir = stat and stat.type == 'file' and vim.fs.dirname(path) or path
  if dir == '' then return vim.fn.getcwd() end

  dir = vim.fs.normalize(dir)
  local root = nil

  while dir and dir ~= '' do
    if is_project_root(dir) then
      root = dir
    end

    local parent = vim.fs.dirname(dir)
    if parent == dir then break end
    dir = parent
  end

  return root or vim.fn.getcwd()
end

local phpactor_lsp_config = {
  settings = {
    language_server = {
      diagnostic_exclude_paths = {
        '**/node_modules/**',
        '**/var/**',
      },
    },
    indexer = {
      exclude_patterns = {
        '**/node_modules/**',
        '**/var/**',
      },
    },
  },
}

_G.phpactor_root_directory = function() return project_root(0) end

local phpactor_keymaps = {
  { 'n', '<leader>pc', '<cmd>PhpactorContextMenu<CR>', '[P]HPActor [C]ontext menu' },
  { 'n', '<leader>pi', '<cmd>PhpactorImportMissingClasses<CR>', '[P]HPActor [I]mport missing classes' },
  { 'n', '<leader>pI', '<cmd>PhpactorImportClass<CR>', '[P]HPActor import [C]lass' },
  { 'n', '<leader>pn', '<cmd>PhpactorClassNew<CR>', '[P]HPActor [N]ew class' },
  { 'n', '<leader>pe', '<cmd>PhpactorClassExpand<CR>', '[P]HPActor class [E]xpand' },
  { 'n', '<leader>pm', '<cmd>PhpactorMoveFile<CR>', '[P]HPActor [M]ove file' },
  { 'n', '<leader>pM', '<cmd>PhpactorCopyFile<CR>', '[P]HPActor [C]opy file' },
  { 'n', '<leader>pf', '<cmd>PhpactorFindReferences<CR>', '[P]HPActor [F]ind references' },
  { 'n', '<leader>ph', '<cmd>PhpactorHover<CR>', '[P]HPActor [H]over' },
  { 'n', '<leader>pt', '<cmd>PhpactorTransform<CR>', '[P]HPActor [T]ransform' },
  { { 'n', 'v' }, '<leader>px', '<cmd>PhpactorExtractMethod<CR>', '[P]HPActor e[X]tract method' },
  { { 'n', 'v' }, '<leader>pX', '<cmd>PhpactorExtractExpression<CR>', '[P]HPActor e[X]tract expression' },
  { 'n', '<leader>pv', '<cmd>PhpactorChangeVisibility<CR>', '[P]HPActor change [V]isibility' },
  { 'n', '<leader>pa', '<cmd>PhpactorGenerateAccessors<CR>', '[P]HPActor gener[A]te accessors' },
  { 'n', '<leader>pd', '<cmd>PhpactorGotoDefinition<CR>', '[P]HPActor goto [D]efinition' },
  { 'n', '<leader>pD', '<cmd>PhpactorGotoType<CR>', '[P]HPActor goto type [D]efinition' },
  { 'n', '<leader>pr', '<cmd>PhpactorGotoImplementations<CR>', '[P]HPActor goto [R] implementations' },
}

local function run_phpactor_override(buf)
  local ok, err = pcall(vim.fn['phpactor#rpc'], 'override_method', {
    source = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n'),
    path = vim.api.nvim_buf_get_name(buf),
  })
  if not ok then
    vim.notify(err, vim.log.levels.ERROR)
    return false
  end

  return true
end

local function set_phpactor_keymaps(buf)
  for _, map in ipairs(phpactor_keymaps) do
    vim.keymap.set(map[1], map[2], map[3], { buffer = buf, desc = map[4] })
  end

  vim.keymap.set('n', '<leader>po', function()
    run_phpactor_override(buf)
  end, {
    buffer = buf,
    desc = '[P]HPActor [O]verride method',
  })

  vim.keymap.set('n', '<leader>pR', vim.lsp.buf.rename, {
    buffer = buf,
    desc = '[P]HPActor [R]ename symbol',
  })
end

vim.cmd([[
  function! PhpactorRootDirectoryStrategyFn() abort
    return v:lua.phpactor_root_directory()
  endfunction
  let g:PhpactorRootDirectoryStrategy = function('PhpactorRootDirectoryStrategyFn')

  function! PhpactorInputListConfirmStrategy(label, choices, multi, ResultHandler) abort
    if a:multi
      return phpactor#input#list#inputlist(a:label, a:choices, a:multi, a:ResultHandler)
    endif

    let l:options = []
    for l:index in range(len(a:choices))
      call add(l:options, '&' . (l:index + 1) . ' ' . a:choices[l:index])
    endfor

    let l:choice = confirm(a:label, join(l:options, "\n"))
    if l:choice == 0
      throw 'cancelled'
    endif

    call a:ResultHandler(a:choices[l:choice - 1])
  endfunction

  let g:phpactorInputListStrategy = 'PhpactorInputListConfirmStrategy'
]])

local function set_project_cwd(args)
  local buf = args.buf
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return end
  if vim.bo[buf].buftype ~= '' then return end

  local name = vim.api.nvim_buf_get_name(buf)
  if name == '' then return end

  local root = project_root(name)
  if root == vim.fn.getcwd() then return end

  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_get_current_buf() == buf then
      vim.cmd.cd(vim.fn.fnameescape(root))
    end
  end)
end

vim.api.nvim_create_autocmd({ 'BufEnter', 'VimEnter' }, {
  desc = 'Update cwd to current buffer project root',
  group = vim.api.nvim_create_augroup('kickstart-project-cwd', { clear = true }),
  callback = set_project_cwd,
})

vim.api.nvim_create_autocmd('FileType', {
  desc = 'PHPActor keymaps',
  group = vim.api.nvim_create_augroup('kickstart-phpactor-keymaps', { clear = true }),
  pattern = 'php',
  callback = function(args)
    vim.g.phpactorPhpBin = 'php'
    vim.g.phpactorbinpath = vim.fn.stdpath 'data' .. '/mason/packages/phpactor/phpactor.phar'
    set_phpactor_keymaps(args.buf)
  end,
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
require('lazy').setup({
  -- NOTE: Plugins can be added via a link or github org/name. To run setup automatically, use `opts = {}`
  { 'NMAC427/guess-indent.nvim', opts = {} },
  {
    'rmagatti/auto-session',
    lazy = false,
    opts = {
      auto_restore = true,
      auto_save = true,
      cwd_change_handling = false,
      suppressed_dirs = { '/', '~/Downloads', '/mnt/c/Program Files/Neovide' },
      session_lens = {
        load_on_setup = true,
        previewer = true,
      },
    },
  },

  -- Alternatively, use `config = function() ... end` for full control over the configuration.
  -- If you prefer to call `setup` explicitly, use:
  --    {
  --        'lewis6991/gitsigns.nvim',
  --        config = function()
  --            require('gitsigns').setup({
  --                -- Your gitsigns configuration here
  --            })
  --        end,
  --    }
  --
  -- See `:help gitsigns` to understand what the configuration keys do
  { -- Adds git related signs to the gutter, as well as utilities for managing changes
    'lewis6991/gitsigns.nvim',
    ---@module 'gitsigns'
    ---@type Gitsigns.Config
    ---@diagnostic disable-next-line: missing-fields
    opts = {
      signs = {
        add = { text = '+' }, ---@diagnostic disable-line: missing-fields
        change = { text = '~' }, ---@diagnostic disable-line: missing-fields
        delete = { text = '_' }, ---@diagnostic disable-line: missing-fields
        topdelete = { text = '‾' }, ---@diagnostic disable-line: missing-fields
        changedelete = { text = '~' }, ---@diagnostic disable-line: missing-fields
      },
      on_attach = function(bufnr)
        local gitsigns = require 'gitsigns'

        local function map(mode, lhs, rhs, opts)
          opts = opts or {}
          opts.buffer = bufnr
          vim.keymap.set(mode, lhs, rhs, opts)
        end

        map('n', ']c', function()
          if vim.wo.diff then
            vim.cmd.normal { ']c', bang = true }
          else
            gitsigns.nav_hunk 'next'
          end
        end, { desc = 'Jump to next git [c]hange' })

        map('n', '[c', function()
          if vim.wo.diff then
            vim.cmd.normal { '[c', bang = true }
          else
            gitsigns.nav_hunk 'prev'
          end
        end, { desc = 'Jump to previous git [c]hange' })

        map('v', '<leader>hs', function() gitsigns.stage_hunk { vim.fn.line '.', vim.fn.line 'v' } end, { desc = 'git [s]tage hunk' })
        map('v', '<leader>hr', function() gitsigns.reset_hunk { vim.fn.line '.', vim.fn.line 'v' } end, { desc = 'git [r]eset hunk' })
        map('n', '<leader>hs', gitsigns.stage_hunk, { desc = 'git [s]tage hunk' })
        map('n', '<leader>hr', gitsigns.reset_hunk, { desc = 'git [r]eset hunk' })
        map('n', '<leader>hS', gitsigns.stage_buffer, { desc = 'git [S]tage buffer' })
        map('n', '<leader>hu', gitsigns.stage_hunk, { desc = 'git [u]ndo stage hunk' })
        map('n', '<leader>hR', gitsigns.reset_buffer, { desc = 'git [R]eset buffer' })
        map('n', '<leader>hp', gitsigns.preview_hunk, { desc = 'git [p]review hunk' })
        map('n', '<leader>hb', gitsigns.blame_line, { desc = 'git [b]lame line' })
        map('n', '<leader>hd', gitsigns.diffthis, { desc = 'git [d]iff against index' })
        map('n', '<leader>hD', function() gitsigns.diffthis '@' end, { desc = 'git [D]iff against last commit' })
        map('n', '<leader>tb', gitsigns.toggle_current_line_blame, { desc = '[T]oggle git show [b]lame line' })
        map('n', '<leader>tD', gitsigns.preview_hunk_inline, { desc = '[T]oggle git show [D]eleted' })
      end,
    },
  },

  -- NOTE: Plugins can also be configured to run Lua code when they are loaded.
  --
  -- This is often very useful to both group configuration, as well as handle
  -- lazy loading plugins that don't need to be loaded immediately at startup.
  --
  -- For example, in the following configuration, we use:
  --  event = 'VimEnter'
  --
  -- which loads which-key before all the UI elements are loaded. Events can be
  -- normal autocommands events (`:help autocmd-events`).
  --
  -- Then, because we use the `opts` key (recommended), the configuration runs
  -- after the plugin has been loaded as `require(MODULE).setup(opts)`.

  { -- Useful plugin to show you pending keybinds.
    'folke/which-key.nvim',
    event = 'VimEnter',
    ---@module 'which-key'
    ---@type wk.Opts
    ---@diagnostic disable-next-line: missing-fields
    opts = {
      -- delay between pressing a key and opening which-key (milliseconds)
      delay = 0,
      icons = { mappings = vim.g.have_nerd_font },

      -- Document existing key chains
      spec = {
        { '<leader>s', group = '[S]earch', mode = { 'n', 'v' } },
        { '<leader>p', group = '[P]HP Actions' },
        { '<leader>t', group = '[T]oggle' },
        { '<leader>h', group = 'Git [H]unk', mode = { 'n', 'v' } }, -- Enable gitsigns recommended keymaps first
        { 'gr', group = 'LSP Actions', mode = { 'n' } },
      },
    },
  },

  { -- Fuzzy Finder (files, lsp, etc)
    'nvim-telescope/telescope.nvim',
    enabled = true,
    event = 'VimEnter',
    dependencies = {
      'nvim-lua/plenary.nvim',
      { -- If encountering errors, see telescope-fzf-native README for installation instructions
        'nvim-telescope/telescope-fzf-native.nvim',

        -- `build` is used to run some command when the plugin is installed/updated.
        -- This is only run then, not every time Neovim starts up.
        build = 'make',

        -- `cond` is a condition used to determine whether this plugin should be
        -- installed and loaded.
        cond = function() return vim.fn.executable 'make' == 1 end,
      },
      { 'nvim-telescope/telescope-ui-select.nvim' },

      -- Useful for getting pretty icons, but requires a Nerd Font.
      { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
    },
    config = function()
      require('telescope').setup {
        -- pickers = {}
        extensions = {
          ['ui-select'] = { require('telescope.themes').get_dropdown() },
        },
      }

      -- Enable Telescope extensions if they are installed
      pcall(require('telescope').load_extension, 'fzf')
      pcall(require('telescope').load_extension, 'ui-select')
      -- See `:help telescope.builtin`
      local builtin = require 'telescope.builtin'
      vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
      vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
      vim.keymap.set('n', '<leader>sf', function()
        builtin.find_files {
          hidden = true,
          no_ignore = true,
          file_ignore_patterns = {
            '^.git/',
            '^node_modules/',
            '/node_modules/',
          },
        }
      end, { desc = '[S]earch [F]iles' })
      vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = '[S]earch [S]elect Telescope' })
      vim.keymap.set({ 'n', 'v' }, '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
      vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })
      vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
      vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
      vim.keymap.set('n', '<leader>s.', function()
        builtin.oldfiles {
          cwd_only = false,
          include_current_session = true,
        }
      end, { desc = '[S]earch Recent Files ("." for repeat)' })
      vim.keymap.set('n', '<leader>sc', builtin.commands, { desc = '[S]earch [C]ommands' })
      vim.keymap.set('n', '<leader>sL', '<cmd>AutoSession search<CR>', { desc = '[S]earch Session [L]ist' })
      vim.keymap.set('n', '<leader>sS', '<cmd>SessionSave<CR>', { desc = '[S]ession [S]ave' })
      vim.keymap.set('n', '<leader>sD', '<cmd>SessionDelete<CR>', { desc = '[S]ession [D]elete' })
      vim.keymap.set('n', '<leader><leader>', builtin.buffers, { desc = '[ ] Find existing buffers' })

      -- Override default behavior and theme when searching
      vim.keymap.set('n', '<leader>/', function()
        -- You can pass additional configuration to Telescope to change the theme, layout, etc.
        builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
          winblend = 10,
          previewer = false,
        })
      end, { desc = '[/] Fuzzily search in current buffer' })

      -- It's also possible to pass additional configuration options.
      --  See `:help telescope.builtin.live_grep()` for information about particular keys
      vim.keymap.set(
        'n',
        '<leader>s/',
        function()
          builtin.live_grep {
            grep_open_files = true,
            prompt_title = 'Live Grep in Open Files',
          }
        end,
        { desc = '[S]earch [/] in Open Files' }
      )

      -- Shortcut for searching your Neovim configuration files
      vim.keymap.set('n', '<leader>sn', function() builtin.find_files { cwd = vim.fn.stdpath 'config' } end, { desc = '[S]earch [N]eovim files' })
    end,
  },

  -- LSP Plugins
  {
    -- Main LSP Configuration
    'neovim/nvim-lspconfig',
    dependencies = {
      -- NOTE: `opts = {}` is the same as calling `require('mason').setup({})`
      {
        'mason-org/mason.nvim',
        ---@module 'mason.settings'
        ---@type MasonSettings
        ---@diagnostic disable-next-line: missing-fields
        opts = {},
      },
      -- Maps LSP server names between nvim-lspconfig and Mason package names.
      'mason-org/mason-lspconfig.nvim',
      'WhoIsSethDaniel/mason-tool-installer.nvim',

      -- Useful status updates for LSP.
      { 'j-hui/fidget.nvim', opts = {} },
    },
    config = function()
      local builtin = require 'telescope.builtin'
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
        callback = function(event)
          -- In this case, we create a function that lets us more easily define mappings specific
          -- for LSP related items. It sets the mode, buffer and description for us each time.
          local map = function(keys, func, desc, mode)
            mode = mode or 'n'
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
          end

          -- Rename the variable under your cursor.
          --  Most Language Servers support renaming across files, etc.
          map('grn', vim.lsp.buf.rename, '[R]e[n]ame')

          -- Find references for the word under your cursor.
          map('grr', builtin.lsp_references, '[G]oto [R]eferences')

          -- Execute a code action, usually your cursor needs to be on top of an error
          -- or a suggestion from your LSP for this to activate.
          map('gra', vim.lsp.buf.code_action, '[G]oto Code [A]ction', { 'n', 'x' })

          -- WARN: This is not Goto Definition, this is Goto Declaration.
          --  For example, in C this would take you to the header.
          map('grD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

          -- Jump to the implementation of the word under your cursor.
          map('gri', builtin.lsp_implementations, '[G]oto [I]mplementation')

          -- Jump to the definition of the word under your cursor.
          map('grd', builtin.lsp_definitions, '[G]oto [D]efinition')

          -- Jump to the type of the word under your cursor.
          map('grt', builtin.lsp_type_definitions, '[G]oto [T]ype Definition')

          -- Fuzzy find symbols in the current document or workspace.
          map('gO', builtin.lsp_document_symbols, 'Open Document Symbols')
          map('gW', builtin.lsp_dynamic_workspace_symbols, 'Open Workspace Symbols')

          -- The following two autocommands are used to highlight references of the
          -- word under your cursor when your cursor rests there for a little while.
          --    See `:help CursorHold` for information about when this is executed
          --
          -- When you move your cursor, the highlights will be cleared (the second autocommand).
          local client = vim.lsp.get_client_by_id(event.data.client_id)

          if client and client.name == 'phpactor' then
            client.server_capabilities.completionProvider = nil
          end

          if client and client.name ~= 'phpactor' and client:supports_method('textDocument/documentHighlight', event.buf) then
            local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
            vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.document_highlight,
            })

            vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.clear_references,
            })

            vim.api.nvim_create_autocmd('LspDetach', {
              group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
              callback = function(event2)
                vim.lsp.buf.clear_references()
                vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
              end,
            })
          end

          if client and client:supports_method('textDocument/inlayHint', event.buf) then
            map('<leader>th', function() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf }) end, '[T]oggle Inlay [H]ints')
          end
        end,
      })

      ---@type table<string, vim.lsp.Config>
      local servers = {
        intelephense = {
          settings = {
            intelephense = {
              files = {
                exclude = {
                  '**/node_modules/**',
                  '**/var/**',
                },
              },
              telemetry = {
                enabled = false,
              },
            },
          },
        },
        phpactor = phpactor_lsp_config,
        yamlls = {},
        twiggy_language_server = {},
        ts_ls = {},
        stylua = {}, -- Used to format Lua code

        -- Special Lua Config, as recommended by neovim help docs
        lua_ls = {
          root_dir = project_root,
          on_init = function(client)
            if client.workspace_folders then
              local path = client.workspace_folders[1].name
              if path ~= vim.fn.stdpath 'config' and (vim.uv.fs_stat(path .. '/.luarc.json') or vim.uv.fs_stat(path .. '/.luarc.jsonc')) then return end
            end

            client.config.settings.Lua = vim.tbl_deep_extend('force', client.config.settings.Lua, {
              runtime = {
                version = 'LuaJIT',
                path = { 'lua/?.lua', 'lua/?/init.lua' },
              },
              workspace = {
                checkThirdParty = false,
                -- NOTE: this is a lot slower and will cause issues when working on your own configuration.
                --  See https://github.com/neovim/nvim-lspconfig/issues/3189
                library = vim.tbl_extend('force', vim.api.nvim_get_runtime_file('', true), {
                  '${3rd}/luv/library',
                  '${3rd}/busted/library',
                }),
              },
            })
          end,
          settings = {
            Lua = {},
          },
        },
      }

      local ensure_installed = vim.tbl_keys(servers or {})
      vim.list_extend(ensure_installed, {
        -- You can add other tools here that you want Mason to install
      })

      require('mason-tool-installer').setup { ensure_installed = ensure_installed }

      for name, server in pairs(servers) do
        vim.lsp.config(name, server)
        vim.lsp.enable(name)
      end
    end,
  },

  { -- Autoformat
    'stevearc/conform.nvim',
    cmd = { 'ConformInfo' },
    keys = {
      {
        '<leader>f',
        function() require('conform').format { async = true, lsp_format = 'fallback' } end,
        mode = 'n',
        desc = '[F]ormat buffer',
      },
      {
        '<leader>f',
        function()
          require('conform').format {
            async = true,
            lsp_format = 'fallback',
            range = {
              start = vim.api.nvim_buf_get_mark(0, '<'),
              ['end'] = vim.api.nvim_buf_get_mark(0, '>'),
            },
          }
        end,
        mode = 'v',
        desc = '[F]ormat selection',
      },
    },
    ---@module 'conform'
    ---@type conform.setupOpts
    opts = {
      notify_on_error = false,
      format_on_save = nil,
      formatters_by_ft = {
        lua = { 'stylua' },
        php = { 'php_cs_fixer' },
      },
    },
  },

  { -- Autocompletion
    'saghen/blink.cmp',
    event = 'VimEnter',
    version = '1.*',
    dependencies = {
      'rafamadriz/friendly-snippets',
    },
    ---@module 'blink.cmp'
    ---@type blink.cmp.Config
    opts = {
      keymap = {
        -- See :h blink-cmp-config-keymap for defining your own keymap
        preset = 'default',
        ['<Tab>'] = { 'select_and_accept', 'snippet_forward', 'fallback' },
        ['<S-Tab>'] = { 'snippet_backward', 'fallback' },
      },

      appearance = {
        -- Adjusts spacing to ensure icons are aligned
        nerd_font_variant = 'mono',
      },

      completion = {
        list = {
          selection = {
            preselect = true,
            auto_insert = false,
          },
        },
        -- By default, you may press `<c-space>` to show the documentation.
        -- Optionally, set `auto_show = true` to show the documentation after a delay.
        documentation = { auto_show = false, auto_show_delay_ms = 500 },
      },

      sources = {
        default = { 'lsp', 'path', 'snippets', 'codecompanion' },
        providers = {
          codecompanion = {
            name = 'CodeCompanion',
            module = 'codecompanion.providers.completion.blink',
            enabled = true,
          },
        },
      },

      snippets = { preset = 'mini_snippets' },

      -- See :h blink-cmp-config-fuzzy for more information
      fuzzy = { implementation = 'lua' },

      -- Shows a signature help window while you type arguments for a function
      signature = { enabled = true },
    },
  },
  {
    'rebelot/kanagawa.nvim',
    priority = 1000,
    config = function() vim.cmd.colorscheme 'kanagawa-wave' end,
  },
  {
    'zbirenbaum/copilot.lua',
    event = 'InsertEnter',
    cmd = 'Copilot',
    config = function()
      require('copilot').setup {
        suggestion = {
          enabled = true,
          auto_trigger = true,
          debounce = 75,
          keymap = {
            accept = '<C-l>',
            accept_word = '<C-g>',
            accept_line = false,
            next = '<M-]>',
            prev = '<M-[>',
            dismiss = '<C-]>',
          },
        },
        panel = {
          enabled = false,
        },
        filetypes = {
          markdown = true,
          help = false,
          gitcommit = true,
          yaml = true,
        },
        copilot_node_command = '/home/pat/.nvm/versions/node/v22.16.0/bin/node',
      }

      require('copilot.command').enable()
    end,
  },
  -- Highlight todo, notes, etc in comments
  {
    'folke/todo-comments.nvim',
    event = 'VimEnter',
    dependencies = { 'nvim-lua/plenary.nvim' },
    ---@module 'todo-comments'
    ---@type TodoOptions
    ---@diagnostic disable-next-line: missing-fields
    opts = { signs = false },
  },
  {
    'SmiteshP/nvim-navic',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      require('nvim-navic').setup {
        highlight = true,
        safe_output = true,
        lsp = {
          auto_attach = true,
          preference = { 'intelephense', 'phpactor' },
        },
      }
    end,
  },
  { -- Collection of various small independent plugins/modules
    'nvim-mini/mini.nvim',
    config = function()
      -- Better Around/Inside textobjects
      --
      -- Examples:
      --  - va)  - [V]isually select [A]round [)]paren
      --  - yinq - [Y]ank [I]nside [N]ext [Q]uote
      --  - ci'  - [C]hange [I]nside [']quote
      require('mini.ai').setup { n_lines = 500 }

      -- Add/delete/replace surroundings (brackets, quotes, etc.)
      --
      -- - saiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
      -- - sd'   - [S]urround [D]elete [']quotes
      -- - sr)'  - [S]urround [R]eplace [)] [']
      require('mini.surround').setup()

      require('mini.comment').setup()
      require('mini.move').setup()
      require('mini.operators').setup()

      local mini_snippets = require 'mini.snippets'
      mini_snippets.setup {
        snippets = {
          mini_snippets.gen_loader.from_lang {
            lang_patterns = {
              php = { 'php/**/*.json', '**/php.json', 'html.json', 'javascript/**/*.json', 'global.json' },
              twig = { 'twig/**/*.json', '**/twig.json', 'html.json', 'global.json' },
            },
          },
        },
      }

      -- Simple and easy statusline.
      local statusline = require 'mini.statusline'
      statusline.section_location = function() return '%2l:%-2v' end
      statusline.setup {
        use_icons = vim.g.have_nerd_font,
        content = {
          active = function()
            local mode, mode_hl = statusline.section_mode { trunc_width = 120 }
            local git = statusline.section_git { trunc_width = 40 }
            local diff = statusline.section_diff { trunc_width = 75 }
            local diagnostics = statusline.section_diagnostics { trunc_width = 75 }
            local lsp = statusline.section_lsp { trunc_width = 75 }
            local filename = statusline.section_filename { trunc_width = 140 }
            local fileinfo = statusline.section_fileinfo { trunc_width = 120 }
            local location = statusline.section_location { trunc_width = 75 }
            local search = statusline.section_searchcount { trunc_width = 75 }

            local navic_location = ''
            local ok, navic = pcall(require, 'nvim-navic')
            if ok and navic.is_available() then navic_location = navic.get_location() end

            return statusline.combine_groups {
              { hl = mode_hl, strings = { mode } },
              { hl = 'MiniStatuslineDevinfo', strings = { git, diff, diagnostics, lsp } },
              '%<',
              { hl = 'MiniStatuslineFilename', strings = { filename, navic_location } },
              '%=',
              { hl = 'MiniStatuslineFileinfo', strings = { fileinfo } },
              { hl = mode_hl, strings = { search, location } },
            }
          end,
        },
      }

      -- ... and there is more!
      --  Check out: https://github.com/nvim-mini/mini.nvim
    end,
  },

  { -- Highlight, edit, and navigate code
    'nvim-treesitter/nvim-treesitter',
    lazy = false,
    build = ':TSUpdate',
    branch = 'main',
    -- [[ Configure Treesitter ]] See `:help nvim-treesitter-intro`
    config = function()
      local parsers = { 'bash', 'diff', 'html', 'lua', 'luadoc', 'markdown', 'markdown_inline', 'php', 'query', 'vim', 'vimdoc', 'yaml', 'javascript', 'twig' }
      require('nvim-treesitter').install(parsers)
      vim.api.nvim_create_autocmd('FileType', {
        callback = function(args)
          local buf, filetype = args.buf, args.match

          local language = vim.treesitter.language.get_lang(filetype)
          if not language then return end

          -- check if parser exists and load it
          if not vim.treesitter.language.add(language) then return end
          -- enables syntax highlighting and other treesitter features
          vim.treesitter.start(buf, language)

          -- enables treesitter based folds
          -- for more info on folds see `:help folds`
          -- vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
          -- vim.wo.foldmethod = 'expr'

          -- enables treesitter based indentation
          vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end,
      })
    end,
  },
  {
    'phpactor/phpactor',
    build = 'composer install --no-dev -o',
    ft = 'php',
  },
  {
    'olimorris/codecompanion.nvim',
    version = '^19.0.0',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-treesitter/nvim-treesitter',
    },
    opts = {
      adapters = {
        http = {
          openai = function()
            return require('codecompanion.adapters').extend('openai', {
              env = {
                api_key = 'OPENAI_API_KEY',
              },
            })
          end,
        },
        acp = {
          codex = function()
            return require('codecompanion.adapters').extend('codex', {
              defaults = {
                auth_method = 'chatgpt',
              },
            })
          end,
        },
      },
      strategies = {
        chat = {
          adapter = 'codex',
        },
        inline = {
          adapter = 'openai_responses',
        },
        cmd = {
          adapter = 'codex',
        },
        cli = {
          agents = {
            codex = {
              cmd = 'codex',
              args = {},
              description = 'OpenAI Codex CLI',
            },
            openai = {
              cmd = 'codex',
              args = {},
              description = 'OpenAI Codex CLI',
            },
          },
        },
      },
    },
  },

  require 'kickstart.plugins.debug',
  require 'kickstart.plugins.indent_line',
  require 'kickstart.plugins.lint',
  require 'kickstart.plugins.autopairs',
  require 'kickstart.plugins.neo-tree',
  -- Add Git support
  {
    'kdheepak/lazygit.nvim',
    cmd = {
      'LazyGit',
      'LazyGitCurrentFile',
      'LazyGitFilter',
      'LazyGitFilterCurrentFile',
    },
    dependencies = {
      'nvim-lua/plenary.nvim',
    },
    keys = {
      {
        '<leader>gg',
        function()
          local bufname = vim.api.nvim_buf_get_name(0)
          local git_root = project_root(bufname ~= '' and bufname or vim.uv.cwd())

          if vim.uv.fs_stat(vim.fs.joinpath(git_root, '.git')) ~= nil then
            require('lazygit').lazygit(git_root)
          else
            vim.notify('Current buffer is not inside a git repository', vim.log.levels.WARN)
          end
        end,
        desc = 'Open Lazy[G]it for current project',
      },
      { '<leader>gf', '<cmd>LazyGitFilterCurrentFile<CR>', desc = 'Open LazyGit history for current [f]ile' },
    },
  },
}, { ---@diagnostic disable-line: missing-fields
  ui = {
    -- If you are using a Nerd Font: set icons to an empty table which will use the
    -- default lazy.nvim defined Nerd Font icons, otherwise define a unicode icons table
    icons = vim.g.have_nerd_font and {} or {
      cmd = '⌘',
      config = '🛠',
      event = '📅',
      ft = '📂',
      init = '⚙',
      keys = '🗝',
      plugin = '🔌',
      runtime = '💻',
      require = '🌙',
      source = '📄',
      start = '🚀',
      task = '📌',
      lazy = '💤 ',
    },
  },
})

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et
