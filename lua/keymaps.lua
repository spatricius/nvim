local M = {}
local last_symfony_console_command = nil

local function copy_to_clipboard(text, empty_message)
  text = vim.trim(text or '')
  if text == '' then
    vim.notify(empty_message, vim.log.levels.INFO)
    return
  end

  vim.fn.setreg('+', text)
  vim.notify('Copied to clipboard', vim.log.levels.INFO)
end

local function copy_last_message()
  local ok, last_message = pcall(vim.fn.histget, 'message', -1)
  if ok and type(last_message) == 'string' and vim.trim(last_message) ~= '' then
    copy_to_clipboard(last_message, 'No messages to copy')
    return
  end

  local exec_ok, result = pcall(vim.api.nvim_exec2, 'messages', { output = true })
  if not exec_ok then
    vim.notify('Failed to read :messages', vim.log.levels.ERROR)
    return
  end

  local lines = vim.split(result.output or '', '\n', { trimempty = true })
  copy_to_clipboard(lines[#lines] or '', 'No messages to copy')
end

local function copy_all_messages()
  local ok, result = pcall(vim.api.nvim_exec2, 'messages', { output = true })
  if not ok then
    vim.notify('Failed to read :messages', vim.log.levels.ERROR)
    return
  end

  copy_to_clipboard(result.output or '', 'No messages to copy')
end

local function copy_buffer_diagnostics()
  local diagnostics = vim.diagnostic.get(0)
  if vim.tbl_isempty(diagnostics) then
    vim.notify('No diagnostics in current buffer', vim.log.levels.INFO)
    return
  end

  table.sort(diagnostics, function(a, b)
    if a.lnum == b.lnum then return a.col < b.col end
    return a.lnum < b.lnum
  end)

  local lines = {}
  for _, diagnostic in ipairs(diagnostics) do
    table.insert(lines, string.format(
      '%s|%d col %d| %s',
      vim.fn.expand '%:p:.',
      diagnostic.lnum + 1,
      diagnostic.col + 1,
      diagnostic.message:gsub('%s+', ' ')
    ))
  end

  copy_to_clipboard(table.concat(lines, '\n'), 'No diagnostics in current buffer')
end

local function register_group(spec, opts)
  local ok, wk = pcall(require, 'which-key')
  if ok then wk.add({ spec }, opts or {}) end
end

function M.setup()
  -- General editor behavior
  vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')
  vim.keymap.set({ 'i', 'c', 'n' }, '<C-S-V>', '<C-r>+')
  vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })
  vim.keymap.set('n', '<leader>f', function()
    require('conform').format { async = true, lsp_format = 'fallback' }
  end, { desc = '[F]ormat buffer' })
  vim.keymap.set('v', '<leader>f', function()
    require('conform').format {
      async = true,
      lsp_format = 'fallback',
      range = {
        start = vim.api.nvim_buf_get_mark(0, '<'),
        ['end'] = vim.api.nvim_buf_get_mark(0, '>'),
      },
    }
  end, { desc = '[F]ormat selection' })
  vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

  -- Window navigation and movement
  vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
  vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
  vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
  vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

  vim.keymap.set('n', '<C-S-h>', '<C-w>H', { desc = 'Move window to the left' })
  vim.keymap.set('n', '<C-S-l>', '<C-w>L', { desc = 'Move window to the right' })
  vim.keymap.set('n', '<C-S-j>', '<C-w>J', { desc = 'Move window to the lower' })
  vim.keymap.set('n', '<C-S-k>', '<C-w>K', { desc = 'Move window to the upper' })

  -- Project tree
  vim.keymap.set('n', '\\', '<cmd>Neotree reveal<CR>', { desc = 'NeoTree reveal', silent = true })

  -- Symfony console
  register_group({ '<leader>c', group = '[C]onsole' })
  vim.keymap.set('n', '<leader>cc', M.run_symfony_console_prompt, { desc = 'Run Symfony [C]onsole command' })
  vim.keymap.set('n', '<leader>cl', M.select_symfony_console_command, { desc = 'Choose Symfony command from [L]ist' })
  vim.keymap.set('n', '<leader>cr', M.repeat_symfony_console_command, { desc = '[R]epeat last Symfony command' })

  -- Global toggles
  vim.keymap.set('n', '<leader>tb', function()
    local ok, gitsigns = pcall(require, 'gitsigns')
    if not ok then
      vim.notify('gitsigns is not available in this buffer', vim.log.levels.WARN)
      return
    end

    gitsigns.toggle_current_line_blame()
  end, { desc = '[T]oggle git show [B]lame line' })
  vim.keymap.set('n', '<leader>tD', function()
    local ok, gitsigns = pcall(require, 'gitsigns')
    if not ok then
      vim.notify('gitsigns is not available in this buffer', vim.log.levels.WARN)
      return
    end

    gitsigns.toggle_deleted()
  end, { desc = '[T]oggle git show [D]eleted' })

  -- Copy helpers
  vim.keymap.set('n', '<leader>yd', copy_buffer_diagnostics, { desc = '[Y]ank buffer [D]iagnostics' })
  vim.keymap.set('n', '<leader>ym', copy_last_message, { desc = '[Y]ank last [M]essage' })
  vim.keymap.set('n', '<leader>yM', copy_all_messages, { desc = '[Y]ank all [M]essages' })
end

local function open_command_tab(cmd, cwd)
  vim.cmd.tabnew()

  local tabpage = vim.api.nvim_get_current_tabpage()
  local bufnr = vim.api.nvim_get_current_buf()
  vim.bo[bufnr].buflisted = false

  vim.fn.termopen(cmd, {
    cwd = cwd,
    on_exit = function()
      vim.schedule(function()
        if vim.api.nvim_tabpage_is_valid(tabpage) then vim.cmd 'silent! checktime' end
      end)
    end,
  })

  vim.cmd.startinsert()
end

local function symfony_console_context()
  local helpers = require 'helpers'
  local cmd, root = helpers.symfony_console_command(0)
  if cmd == nil then
    vim.notify('Current buffer is not inside a Symfony project', vim.log.levels.WARN)
    return nil
  end

  return cmd, root
end

function M.run_symfony_console(command)
  local cmd, root = symfony_console_context()
  if cmd == nil then return end

  command = vim.trim(command or '')
  if command == '' then return end

  last_symfony_console_command = command
  vim.list_extend(cmd, vim.split(command, '%s+', { trimempty = true }))
  open_command_tab(cmd, root)
end

function M.run_symfony_console_prompt()
  local cmd = symfony_console_context()
  if cmd == nil then return end

  vim.ui.input({ prompt = 'bin/console ', default = last_symfony_console_command or '' }, function(input)
    if input == nil then return end
    M.run_symfony_console(input)
  end)
end

function M.select_symfony_console_command()
  local helpers = require 'helpers'
  local cmd, root = helpers.symfony_console_command(0, { 'list', '--raw' }, { no_tty = true })
  if cmd == nil then
    vim.notify('Current buffer is not inside a Symfony project', vim.log.levels.WARN)
    return
  end

  vim.system(cmd, { cwd = root, text = true }, function(result)
    if result.code ~= 0 then
      vim.schedule(function()
        vim.notify(result.stderr ~= '' and result.stderr or 'Failed to list Symfony console commands', vim.log.levels.ERROR)
      end)
      return
    end

    local commands = {}
    for _, line in ipairs(vim.split(result.stdout, '\n', { trimempty = true })) do
      local command = vim.split(line, ' ', { plain = true, trimempty = true })[1]
      if command and command ~= '_complete' then table.insert(commands, command) end
    end

    vim.schedule(function()
      vim.ui.select(commands, { prompt = 'Symfony console commands' }, function(choice)
        if choice == nil then return end
        M.run_symfony_console(choice)
      end)
    end)
  end)
end

function M.repeat_symfony_console_command()
  if last_symfony_console_command == nil then
    vim.notify('No Symfony console command has been run yet', vim.log.levels.INFO)
    return
  end

  M.run_symfony_console(last_symfony_console_command)
end

function M.setup_debug_keymaps()
  local function with_dap(fn)
    return function()
      require('lazy').load { plugins = { 'mfussenegger/nvim-dap' } }
      fn()
    end
  end

  -- Debugging
  vim.keymap.set('n', '<F5>', with_dap(function() require('dapui').toggle() end), { desc = 'Debug: See last session result.' })
  vim.keymap.set('n', '<F7>', with_dap(function() require('dap').step_into() end), { desc = 'Debug: Step Into' })
  vim.keymap.set('n', '<F8>', with_dap(function() require('dap').step_over() end), { desc = 'Debug: Step Over' })
  vim.keymap.set('n', '<F9>', with_dap(function() require('dap').continue() end), { desc = 'Debug: Start/Continue' })
  vim.keymap.set('n', '<F10>', with_dap(function() require('dap').step_out() end), { desc = 'Debug: Step Out' })
  vim.keymap.set('n', '<leader>b', with_dap(function() require('dap').toggle_breakpoint() end), { desc = 'Debug: Toggle Breakpoint' })
  vim.keymap.set('n', '<leader>B', with_dap(function() require('dap').set_breakpoint(vim.fn.input 'Breakpoint condition: ') end), { desc = 'Debug: Set Breakpoint' })
end

local php_function_node_types = {
  method_declaration = true,
  function_definition = true,
}

local function php_function_node_at_position(buf, row, col)
  local ok, parser = pcall(vim.treesitter.get_parser, buf, 'php')
  if not ok then return nil end

  local tree = parser:parse()[1]
  if tree == nil then return nil end

  local node = tree:root():named_descendant_for_range(row, col, row, col)
  while node do
    if php_function_node_types[node:type()] then return node end
    node = node:parent()
  end

  return nil
end

local function current_php_function_node(buf)
  local cursor = vim.api.nvim_win_get_cursor(0)
  return php_function_node_at_position(buf, cursor[1] - 1, cursor[2])
end

local function set_function_return_type(buf, node, return_type)
  for child in node:iter_children() do
    if child:type() == 'return_type' then
      local start_row, start_col, end_row, end_col = child:range()
      vim.api.nvim_buf_set_text(buf, start_row, start_col, end_row, end_col, { ': ' .. return_type })
      return true
    end

    if child:type() == 'formal_parameters' then
      local _, _, row, col = child:range()
      vim.api.nvim_buf_set_text(buf, row, col, row, col, { ': ' .. return_type })
      return true
    end
  end

  return false
end

local function implementation_targets()
  local params = vim.lsp.util.make_position_params(0, 'utf-8')
  local responses = vim.lsp.buf_request_sync(0, 'textDocument/implementation', params, 2000) or {}
  local targets = {}
  local seen = {}

  local function add_target(uri, range)
    if uri == nil or range == nil then return end
    local key = table.concat({ uri, range.start.line, range.start.character }, ':')
    if seen[key] then return end
    seen[key] = true
    table.insert(targets, { uri = uri, range = range })
  end

  add_target(vim.uri_from_bufnr(0), params.position and { start = params.position, ['end'] = params.position } or nil)

  for _, response in pairs(responses) do
    for _, item in ipairs(response.result or {}) do
      add_target(item.uri or item.targetUri, item.range or item.targetSelectionRange or item.targetRange)
    end
  end

  return targets
end

local function set_return_type_for_implementations(return_type)
  local targets = implementation_targets()
  if vim.tbl_isempty(targets) then
    vim.notify('No implementations found for the current method', vim.log.levels.WARN)
    return
  end

  local updated = 0
  for _, target in ipairs(targets) do
    local bufnr = vim.uri_to_bufnr(target.uri)
    vim.fn.bufload(bufnr)

    local node = php_function_node_at_position(bufnr, target.range.start.line, target.range.start.character)
    if node ~= nil and set_function_return_type(bufnr, node, return_type) then updated = updated + 1 end
  end

  if updated == 0 then
    vim.notify('Could not update any method signatures', vim.log.levels.WARN)
    return
  end

  vim.notify(string.format('Updated %d method signature(s)', updated), vim.log.levels.INFO)
end

function M.set_phpactor_keymaps(buf, run_phpactor_override)
  -- PHPActor buffer-local mappings
  register_group({ '<leader>p', group = '[P]HP Actions' }, { buffer = buf })

  vim.keymap.set('n', '<leader>pc', '<cmd>PhpactorContextMenu<CR>', { buffer = buf, desc = '[P]HPActor [C]ontext menu' })
  vim.keymap.set('n', '<leader>pi', '<cmd>PhpactorImportMissingClasses<CR>', { buffer = buf, desc = '[P]HPActor [I]mport missing classes' })
  vim.keymap.set('n', '<leader>pI', '<cmd>PhpactorImportClass<CR>', { buffer = buf, desc = '[P]HPActor import [C]lass' })
  vim.keymap.set('n', '<leader>pn', '<cmd>PhpactorClassNew<CR>', { buffer = buf, desc = '[P]HPActor [N]ew class' })
  vim.keymap.set('n', '<leader>pe', '<cmd>PhpactorClassExpand<CR>', { buffer = buf, desc = '[P]HPActor class [E]xpand' })
  vim.keymap.set('n', '<leader>pm', '<cmd>PhpactorMoveFile<CR>', { buffer = buf, desc = '[P]HPActor [M]ove file' })
  vim.keymap.set('n', '<leader>pM', '<cmd>PhpactorCopyFile<CR>', { buffer = buf, desc = '[P]HPActor [C]opy file' })
  vim.keymap.set('n', '<leader>pf', '<cmd>PhpactorFindReferences<CR>', { buffer = buf, desc = '[P]HPActor [F]ind references' })
  vim.keymap.set('n', '<leader>ph', '<cmd>PhpactorHover<CR>', { buffer = buf, desc = '[P]HPActor [H]over' })
  vim.keymap.set('n', '<leader>pt', '<cmd>PhpactorTransform<CR>', { buffer = buf, desc = '[P]HPActor [T]ransform' })
  vim.keymap.set({ 'n', 'v' }, '<leader>px', '<cmd>PhpactorExtractMethod<CR>', { buffer = buf, desc = '[P]HPActor e[X]tract method' })
  vim.keymap.set({ 'n', 'v' }, '<leader>pX', '<cmd>PhpactorExtractExpression<CR>', { buffer = buf, desc = '[P]HPActor e[X]tract expression' })
  vim.keymap.set('n', '<leader>pv', '<cmd>PhpactorChangeVisibility<CR>', { buffer = buf, desc = '[P]HPActor change [V]isibility' })
  vim.keymap.set('n', '<leader>pa', '<cmd>PhpactorGenerateAccessors<CR>', { buffer = buf, desc = '[P]HPActor gener[A]te accessors' })
  vim.keymap.set('n', '<leader>pd', '<cmd>PhpactorGotoDefinition<CR>', { buffer = buf, desc = '[P]HPActor goto [D]efinition' })
  vim.keymap.set('n', '<leader>pD', '<cmd>PhpactorGotoType<CR>', { buffer = buf, desc = '[P]HPActor goto type [D]efinition' })
  vim.keymap.set('n', '<leader>pr', '<cmd>PhpactorGotoImplementations<CR>', { buffer = buf, desc = '[P]HPActor goto [R] implementations' })

  vim.keymap.set('n', '<leader>prt', function()
    local node = current_php_function_node(buf)
    if node == nil then
      vim.notify('Cursor is not inside a PHP method or function', vim.log.levels.WARN)
      return
    end

    vim.ui.input({ prompt = 'Return type: ' }, function(input)
      local return_type = vim.trim(input or '')
      if return_type == '' then return end
      set_return_type_for_implementations(return_type)
    end)
  end, {
    buffer = buf,
    desc = '[P]HPActor set [R]eturn [T]ype for implementations',
  })

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

function M.set_gitsigns_keymaps(bufnr, gitsigns)
  local function map(mode, lhs, rhs, opts)
    opts = opts or {}
    opts.buffer = bufnr
    vim.keymap.set(mode, lhs, rhs, opts)
  end

  -- Gitsigns buffer-local mappings
  register_group({ '<leader>h', group = 'Git [H]unk' }, { buffer = bufnr, mode = { 'n', 'v' } })

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
end

function M.set_telescope_keymaps(builtin, live_grep_args, telescope_themes, telescope_opts)
  -- Telescope search mappings
  vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
  vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
  vim.keymap.set('n', '<leader>sf', telescope_opts.find_files, { desc = '[S]earch [F]iles' })
  vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = '[S]earch [S]elect Telescope' })
  vim.keymap.set({ 'n', 'v' }, '<leader>sw', telescope_opts.grep_word, { desc = '[S]earch current [W]ord' })
  vim.keymap.set('n', '<leader>sg', telescope_opts.live_grep, { desc = '[S]earch by [G]rep with args' })
  vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
  vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
  vim.keymap.set('n', '<leader>s.', function()
    builtin.oldfiles {
      cwd_only = false,
      include_current_session = false,
    }
  end, { desc = '[S]earch Recent Files ("." for repeat)' })
  vim.keymap.set('n', '<leader>sc', builtin.commands, { desc = '[S]earch [C]ommands' })
  vim.keymap.set('n', '<leader>sL', '<cmd>AutoSession search<CR>', { desc = '[S]earch Session [L]ist' })
  vim.keymap.set('n', '<leader>sS', '<cmd>SessionSave<CR>', { desc = '[S]ession [S]ave' })
  vim.keymap.set('n', '<leader>sD', '<cmd>SessionDelete<CR>', { desc = '[S]ession [D]elete' })
  vim.keymap.set('n', '<leader><leader>', builtin.buffers, { desc = '[ ] Find existing buffers' })

  vim.keymap.set('n', '<leader>/', function()
    builtin.current_buffer_fuzzy_find(telescope_themes.get_dropdown {
      winblend = 10,
      previewer = false,
    })
  end, { desc = '[/] Fuzzily search in current buffer' })

  vim.keymap.set('n', '<leader>s/', telescope_opts.open_files_grep, { desc = '[S]earch [/] in Open Files' })
  vim.keymap.set('n', '<leader>sn', telescope_opts.find_nvim_files, { desc = '[S]earch [N]eovim files' })
end

function M.set_lsp_keymaps(buf, builtin)
  local map = function(keys, func, desc, mode)
    mode = mode or 'n'
    vim.keymap.set(mode, keys, func, { buffer = buf, desc = 'LSP: ' .. desc })
  end

  -- LSP buffer-local mappings
  map('grn', vim.lsp.buf.rename, '[R]e[n]ame')
  map('grr', builtin.lsp_references, '[G]oto [R]eferences')
  map('gra', vim.lsp.buf.code_action, '[G]oto Code [A]ction', { 'n', 'x' })
  map('grD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')
  map('gri', builtin.lsp_implementations, '[G]oto [I]mplementation')
  map('grd', builtin.lsp_definitions, '[G]oto [D]efinition')
  map('grt', builtin.lsp_type_definitions, '[G]oto [T]ype Definition')
  map('gO', builtin.lsp_document_symbols, 'Open Document Symbols')
  map('gW', builtin.lsp_dynamic_workspace_symbols, 'Open Workspace Symbols')
end

function M.set_lsp_inlay_hint_keymap(buf)
  vim.keymap.set('n', '<leader>th', function()
    vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = buf })
  end, {
    buffer = buf,
    desc = 'LSP: [T]oggle Inlay [H]ints',
  })
end

function M.setup_git_keymaps(git)
  -- Git tools
  vim.keymap.set('n', '<leader>gg', git.open_project_lazygit, { desc = 'Open Lazy[G]it for current project' })
  vim.keymap.set('n', '<leader>gf', git.open_current_file_lazygit, { desc = 'Open LazyGit history for current [f]ile' })
  vim.keymap.set('n', '<leader>gd', function()
    require('lazy').load { plugins = { 'sindrets/diffview.nvim' } }
    vim.cmd.DiffviewOpen()
  end, { desc = 'Open [D]iffview' })
  vim.keymap.set('n', '<leader>gD', function()
    require('lazy').load { plugins = { 'sindrets/diffview.nvim' } }
    vim.cmd.DiffviewClose()
  end, { desc = 'Close [D]iffview' })
  vim.keymap.set('n', '<leader>gh', function()
    require('lazy').load { plugins = { 'sindrets/diffview.nvim' } }
    vim.cmd 'DiffviewFileHistory %'
  end, { desc = 'Current File [H]istory' })
  vim.keymap.set('n', '<leader>gH', function()
    require('lazy').load { plugins = { 'sindrets/diffview.nvim' } }
    vim.cmd.DiffviewFileHistory()
  end, { desc = 'Project [H]istory' })
  vim.keymap.set('n', '<leader>gr', function()
    require('lazy').load { plugins = { 'sindrets/diffview.nvim' } }
    vim.cmd.DiffviewRefresh()
  end, { desc = '[R]efresh Diffview' })
end

return M
