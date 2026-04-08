local helpers = require 'helpers'

local function is_vendor_path(path)
  if type(path) ~= 'string' or path == '' then return false end

  path = path:gsub('\\', '/')
  return path == 'vendor' or path:match('^vendor/') ~= nil or path:match('/vendor/') ~= nil
end

local function with_vendor_bias(base_sorter)
  local original_scoring = base_sorter.scoring_function

  base_sorter.scoring_function = function(self, prompt, line, entry, cb_add, cb_filter)
    local score = original_scoring(self, prompt, line, entry, cb_add, cb_filter)
    if type(score) ~= 'number' or score < 0 then return score end

    local path = entry and (entry.filename or entry.path or entry.value)
    if is_vendor_path(path) then return score + 0.05 end

    return score
  end

  return base_sorter
end

local function vendor_file_sorter(opts)
  return with_vendor_bias(require('telescope.sorters').get_fuzzy_file(opts))
end

local function vendor_generic_sorter(opts)
  return with_vendor_bias(require('telescope.sorters').get_generic_fuzzy_sorter(opts))
end

return {
  'nvim-telescope/telescope.nvim',
  enabled = true,
  event = 'VimEnter',
  dependencies = {
    'nvim-lua/plenary.nvim',
    {
      'nvim-telescope/telescope-fzf-native.nvim',
      build = 'make',
      cond = function() return vim.fn.executable 'make' == 1 end,
    },
    { 'nvim-telescope/telescope-ui-select.nvim' },
    {
      'nvim-telescope/telescope-live-grep-args.nvim',
      version = '^1.1.0',
    },
    { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
  },
  config = function()
    local telescope = require 'telescope'
    local builtin = require 'telescope.builtin'
    local themes = require 'telescope.themes'
    local lga_actions = require 'telescope-live-grep-args.actions'
    local open_with_trouble = require('trouble.sources.telescope').open

    telescope.setup {
      defaults = {
        mappings = {
          i = {
            ['<M-t>'] = open_with_trouble,
          },
          n = {
            ['<M-t>'] = open_with_trouble,
          },
        },
      },
      extensions = {
        live_grep_args = {
          auto_quoting = true,
          mappings = {
            i = {
              ['<C-k>'] = lga_actions.quote_prompt(),
              ['<C-i>'] = lga_actions.quote_prompt { postfix = ' --iglob ' },
              ['<C-t>'] = lga_actions.quote_prompt { postfix = ' -t' },
            },
          },
        },
        ['ui-select'] = { themes.get_dropdown() },
      },
    }

    pcall(telescope.load_extension, 'fzf')
    pcall(telescope.load_extension, 'ui-select')
    pcall(telescope.load_extension, 'live_grep_args')

    local live_grep_args = telescope.extensions.live_grep_args.live_grep_args
    require('keymaps').set_telescope_keymaps(builtin, live_grep_args, themes, {
      find_files = function()
        builtin.find_files {
          hidden = true,
          no_ignore = true,
          sorter = vendor_file_sorter(),
          file_ignore_patterns = helpers.telescope_file_ignore_patterns { include_git = true },
        }
      end,
      grep_word = function()
        builtin.grep_string { sorter = vendor_generic_sorter(), additional_args = helpers.telescope_grep_additional_args }
      end,
      live_grep = function()
        live_grep_args { sorter = vendor_generic_sorter(), additional_args = helpers.telescope_grep_additional_args }
      end,
      open_files_grep = function()
        builtin.live_grep {
          grep_open_files = true,
          prompt_title = 'Live Grep in Open Files',
          sorter = vendor_generic_sorter(),
          additional_args = helpers.telescope_grep_additional_args,
        }
      end,
      find_nvim_files = function()
        builtin.find_files {
          cwd = vim.fn.stdpath 'config',
          sorter = vendor_file_sorter(),
          file_ignore_patterns = helpers.telescope_file_ignore_patterns(),
        }
      end,
    })
  end,
}
