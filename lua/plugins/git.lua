local helpers = require 'helpers'

local M = {}

local function open_lazygit_tab(cmd, cwd)
  local previous_tab = vim.api.nvim_get_current_tabpage()

  vim.cmd.tabnew()

  local tabpage = vim.api.nvim_get_current_tabpage()
  local bufnr = vim.api.nvim_get_current_buf()

  vim.bo[bufnr].buflisted = false

  vim.fn.termopen(cmd, {
    cwd = cwd,
    on_exit = function()
      vim.schedule(function()
        if vim.api.nvim_tabpage_is_valid(tabpage) then
          vim.api.nvim_set_current_tabpage(tabpage)
          vim.cmd 'silent! tabclose'
        end

        if vim.api.nvim_tabpage_is_valid(previous_tab) then
          vim.api.nvim_set_current_tabpage(previous_tab)
        end

        vim.cmd 'silent! checktime'
      end)
    end,
  })

  vim.cmd.startinsert()
end

function M.open_project_lazygit()
  local bufname = vim.api.nvim_buf_get_name(0)
  local git_root = helpers.project_root(bufname ~= '' and bufname or vim.uv.cwd())

  if vim.uv.fs_stat(vim.fs.joinpath(git_root, '.git')) == nil then
    vim.notify('Current buffer is not inside a git repository', vim.log.levels.WARN)
    return
  end

  open_lazygit_tab({ 'lazygit', '-p', git_root }, git_root)
end

function M.open_current_file_lazygit()
  local path = vim.api.nvim_buf_get_name(0)
  if path == '' then
    vim.notify('Current buffer has no file path', vim.log.levels.WARN)
    return
  end

  local git_root = helpers.project_root(path)
  if vim.uv.fs_stat(vim.fs.joinpath(git_root, '.git')) == nil then
    vim.notify('Current buffer is not inside a git repository', vim.log.levels.WARN)
    return
  end

  local relative_path = vim.fs.relpath(git_root, path) or vim.fn.fnamemodify(path, ':.')
  open_lazygit_tab({ 'lazygit', '-p', git_root, '-f', relative_path }, git_root)
end

local spec = {
  {
    'lewis6991/gitsigns.nvim',
    ---@module 'gitsigns'
    ---@type Gitsigns.Config
    ---@diagnostic disable-next-line: missing-fields
    opts = {
      signs = {
        add = { text = '+' },
        change = { text = '~' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
      },
      on_attach = function(bufnr)
        local gitsigns = require 'gitsigns'
        require('keymaps').set_gitsigns_keymaps(bufnr, gitsigns)
      end,
    },
  },
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
  },
  {
    'sindrets/diffview.nvim',
    cmd = {
      'DiffviewOpen',
      'DiffviewFileHistory',
      'DiffviewClose',
      'DiffviewRefresh',
    },
  },
}

require('keymaps').setup_git_keymaps(M)

return spec
