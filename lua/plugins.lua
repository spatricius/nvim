local specs = {
  -- Core editing
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
  {
    'nvim-mini/mini.nvim',
    config = function()
      require('mini.ai').setup { n_lines = 500 }
      require('mini.surround').setup()
      require('mini.comment').setup()
      require('mini.move').setup()
      require('mini.operators').setup {
        replace = { prefix = '' }, -- Disable 'gr' conflict with LSP
      }

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

      local statusline = require 'mini.statusline'
      statusline.section_location = function() return '%2l:%-2v' end
      statusline.setup {
        use_icons = vim.g.have_nerd_font,
        content = {
          active = function()
            local mode, mode_hl = statusline.section_mode { trunc_width = math.huge }
            local summary = vim.b.minigit_summary_string or vim.b.gitsigns_head
            local git = statusline.is_truncated(40) and '' or summary and ((vim.g.have_nerd_font and '' or 'Git') .. ' ' .. (#summary > 20 and summary:sub(1, 20) .. '...' or summary)) or ''
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
              { hl = 'MiniStatuslineDevinfo', strings = { git, diff, diagnostics } },
              '%<',
              { hl = 'MiniStatuslineFilename', strings = { filename, navic_location } },
              '%=',
              -- { hl = 'MiniStatuslineFileinfo', strings = { fileinfo } },
              { hl = mode_hl, strings = { search, location } },
            }
          end,
        },
      }
    end,
  },
  {
    'windwp/nvim-autopairs',
    event = 'InsertEnter',
    opts = {},
  },
  {
    'lukas-reineke/indent-blankline.nvim',
    main = 'ibl',
    ---@module 'ibl'
    ---@type ibl.config
    opts = {},
  },

  -- UI and navigation
  {
    'folke/which-key.nvim',
    event = 'VimEnter',
    ---@module 'which-key'
    ---@type wk.Opts
    ---@diagnostic disable-next-line: missing-fields
    opts = {
      delay = 0,
      icons = { mappings = vim.g.have_nerd_font },
      disable = {
        ft = {
          'dapui_breakpoints',
          'dapui_console',
          'dapui_hover',
          'dapui_scopes',
          'dapui_stacks',
          'dapui_watches',
        },
      },
      spec = {
        { '<leader>c', group = '[C]onsole' },
        { '<leader>g', group = '[G]it' },
        { '<leader>s', group = '[S]earch', mode = { 'n', 'v' } },
        { '<leader>p', group = '[P]HP Actions' },
        { '<leader>t', group = '[T]oggle' },
        { '<leader>x', group = 'Trouble' },
        { '<leader>h', group = 'Git [H]unk', mode = { 'n', 'v' } },
        { 'gr', group = 'LSP Actions', mode = { 'n' } },
      },
    },
  },
  {
    'rebelot/kanagawa.nvim',
    priority = 1000,
    config = function() vim.cmd.colorscheme 'kanagawa-wave' end,
  },
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
    'nvim-neo-tree/neo-tree.nvim',
    version = '*',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-tree/nvim-web-devicons',
      'MunifTanjim/nui.nvim',
    },
    lazy = false,
    ---@module 'neo-tree'
    ---@type neotree.Config
    opts = {
      filesystem = {
        hijack_netrw_behavior = 'disabled',
        filtered_items = {
          visible = true,
          hide_dotfiles = false,
          hide_gitignored = false,
        },
        follow_current_file = {
          enabled = true,
        },
        window = {
          mappings = {
            ['\\'] = 'close_window',
            ['h'] = 'close_node',
            ['l'] = 'open',
          },
        },
      },
    },
  },

  -- Language tooling
  {
    'stevearc/conform.nvim',
    cmd = { 'ConformInfo' },
    opts = {
      notify_on_error = false,
      format_on_save = nil,
      formatters_by_ft = {
        lua = { 'stylua' },
        php = { 'php_cs_fixer' },
      },
      formatters = {
        php_cs_fixer = {
          command = function(_, ctx)
            local helpers = require 'helpers'
            local local_cmd = vim.fs.joinpath(helpers.composer_bin_dir(ctx.filename), 'php-cs-fixer')
            if vim.uv.fs_stat(local_cmd) ~= nil then return local_cmd end
            return 'php-cs-fixer'
          end,
          cwd = function(_, ctx)
            local helpers = require 'helpers'
            return helpers.project_root(ctx.filename)
          end,
        },
      },
    },
  },
  {
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
        preset = 'default',
        ['<Tab>'] = { 'select_and_accept', 'snippet_forward', 'fallback' },
        ['<S-Tab>'] = { 'snippet_backward', 'fallback' },
      },
      appearance = {
        nerd_font_variant = 'mono',
      },
      completion = {
        list = {
          selection = {
            preselect = true,
            auto_insert = false,
          },
        },
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
      fuzzy = { implementation = 'lua' },
      signature = { enabled = true },
    },
  },
  {
    'nvim-treesitter/nvim-treesitter',
    lazy = false,
    build = ':TSUpdate',
    branch = 'main',
    config = function()
      local parsers = { 'bash', 'diff', 'html', 'lua', 'luadoc', 'markdown', 'markdown_inline', 'php', 'query', 'vim', 'vimdoc', 'yaml', 'javascript', 'twig' }
      require('nvim-treesitter').install(parsers)
      vim.api.nvim_create_autocmd('FileType', {
        callback = function(args)
          local buf, filetype = args.buf, args.match

          local language = vim.treesitter.language.get_lang(filetype)
          if not language then return end

          if not vim.treesitter.language.add(language) then return end
          vim.treesitter.start(buf, language)
          vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end,
      })
    end,
  },
  {
    'mfussenegger/nvim-lint',
    event = { 'BufReadPre', 'BufNewFile' },
    config = function()
      local helpers = require 'helpers'
      local lint = require 'lint'

      local phpstan = type(lint.linters.phpstan) == 'function' and lint.linters.phpstan() or vim.deepcopy(lint.linters.phpstan)

      local function project_phpstan(bufnr)
        local root = helpers.project_root(bufnr)
        local cmd = vim.fs.joinpath(helpers.composer_bin_dir(bufnr), 'phpstan')
        if vim.uv.fs_stat(cmd) == nil then return nil end

        return cmd, root
      end

      local function phpstan_buffer_args(bufnr)
        local _, root = project_phpstan(bufnr)
        if root == nil then return nil end

        local path = vim.api.nvim_buf_get_name(bufnr)
        local relative = vim.fs.relpath(root, path)

        return {
          'analyze',
          '--error-format=json',
          '--no-progress',
          relative or path,
        }
      end

      local function phpstan_parser(output, bufnr)
        if output == nil or vim.trim(output) == '' then return {} end

        local ok, decoded = pcall(vim.json.decode, output)
        if not ok or type(decoded) ~= 'table' or type(decoded.files) ~= 'table' then return {} end

        local function global_error_diagnostics()
          local diagnostics = {}

          for _, message in ipairs(decoded.errors or {}) do
            table.insert(diagnostics, {
              lnum = 0,
              col = 0,
              message = message,
              source = 'phpstan',
              severity = vim.diagnostic.severity.ERROR,
            })
          end

          return diagnostics
        end

        local root = helpers.project_root(bufnr)
        local bufname = vim.fs.normalize(vim.api.nvim_buf_get_name(bufnr))
        local relative = vim.fs.relpath(root, bufname)
        local file = decoded.files[bufname] or decoded.files[relative]

        if file == nil then
          for path, candidate in pairs(decoded.files) do
            local resolved = vim.fs.normalize(vim.fs.joinpath(root, path))
            if resolved == bufname then
              file = candidate
              break
            end
          end
        end

        if file == nil then return global_error_diagnostics() end

        local diagnostics = {}
        for _, message in ipairs(file.messages or {}) do
          table.insert(diagnostics, {
            lnum = type(message.line) == 'number' and (message.line - 1) or 0,
            col = 0,
            message = message.message,
            source = 'phpstan',
            code = message.identifier,
          })
        end

        vim.list_extend(diagnostics, global_error_diagnostics())

        return diagnostics
      end

      lint.linters.phpstan = function()
        local bufnr = vim.api.nvim_get_current_buf()
        local cmd, root = project_phpstan(bufnr)
        if cmd == nil then return nil end

        local linter = vim.deepcopy(phpstan)
        linter.cmd = cmd
        linter.cwd = root
        linter.args = phpstan_buffer_args(bufnr)
        linter.parser = phpstan_parser
        return linter
      end

      local function has_yamllint()
        return vim.fn.executable 'yamllint' == 1
      end

      lint.linters_by_ft = {
        markdown = { 'markdownlint' },
        php = { 'phpstan' },
        yaml = { 'yamllint' },
      }

      local lint_augroup = vim.api.nvim_create_augroup('lint', { clear = true })
      vim.api.nvim_create_autocmd({ 'InsertLeave', 'TextChanged', 'TextChangedI' }, {
        group = lint_augroup,
        callback = function()
          if not vim.bo.modifiable then return end

          if vim.bo.filetype == 'yaml' and not has_yamllint() then return end
          if vim.bo.filetype == 'php' then return end

          lint.try_lint()
        end,
      })

      vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufWritePost' }, {
        group = lint_augroup,
        callback = function(args)
          if vim.bo[args.buf].filetype ~= 'php' or project_phpstan(args.buf) == nil then return end
          lint.try_lint('phpstan')
        end,
      })

      pcall(vim.api.nvim_del_user_command, 'PhpstanLint')
      vim.api.nvim_create_user_command('PhpstanLint', function()
        if project_phpstan(0) == nil then
          vim.notify('No project-local Composer phpstan binary found', vim.log.levels.WARN)
          return
        end

        if vim.bo.modified then vim.cmd.write() end
        lint.try_lint('phpstan')
      end, { desc = 'Run PHPStan for current buffer' })

      pcall(vim.api.nvim_del_user_command, 'PhpstanInfo')
      vim.api.nvim_create_user_command('PhpstanInfo', function()
        local root = helpers.project_root(0)
        local bin_dir = helpers.composer_bin_dir(0)
        local cmd = vim.fs.joinpath(bin_dir, 'phpstan')
        local exists = vim.uv.fs_stat(cmd) ~= nil

        vim.notify(table.concat({
          'Project root: ' .. root,
          'Composer bin dir: ' .. bin_dir,
          'PHPStan binary: ' .. cmd,
          'Exists: ' .. tostring(exists),
        }, '\n'), vim.log.levels.INFO)
      end, { desc = 'Show resolved PHPStan paths' })
    end,
  },

  -- AI assistants
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
}

local function add_specs(module)
  local plugin_specs = require(module)

  if plugin_specs[1] ~= nil and type(plugin_specs[1]) == 'table' then
    vim.list_extend(specs, plugin_specs)
    return
  end

  table.insert(specs, plugin_specs)
end

add_specs 'plugins.telescope'
add_specs 'plugins.trouble'
add_specs 'plugins.spectre'
add_specs 'plugins.debug'
add_specs 'plugins.git'
add_specs 'plugins.lsp'

require('lazy').setup(specs, {
  ui = {
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
