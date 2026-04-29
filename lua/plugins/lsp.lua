local helpers = require 'helpers'

local symfony_yaml_custom_tags = {
  '!service scalar',
  '!tagged scalar',
  '!tagged_iterator scalar',
  '!tagged_locator scalar',
  '!php/const scalar',
  '!php/enum scalar',
  '!closure scalar',
  '!abstract scalar',
  '!returns_clone scalar',
  '!iterator sequence',
}

_G.phpactor_root_directory = function() return helpers.project_root(0) end

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

vim.cmd [[
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
]]

return {
  {
    'neovim/nvim-lspconfig',
    dependencies = {
      {
        'mason-org/mason.nvim',
        ---@module 'mason.settings'
        ---@type MasonSettings
        ---@diagnostic disable-next-line: missing-fields
        opts = {},
      },
      'mason-org/mason-lspconfig.nvim',
      'WhoIsSethDaniel/mason-tool-installer.nvim',
      { 'j-hui/fidget.nvim', opts = {} },
    },
    config = function()
      local builtin = require 'telescope.builtin'

      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('config-lsp-attach', { clear = true }),
        callback = function(event)
          local client = vim.lsp.get_client_by_id(event.data.client_id)

          if client and client.name == 'intelephense' then
            client.settings = vim.tbl_deep_extend('force', client.settings or {}, {
              intelephense = {
                files = {
                  maxSize = 10000000,
                  associations = { '*.php', '*.phtml' },
                  exclude = {
                    '**/.git/**',
                    '**/node_modules/**',
                    '**/var/cache/**',
                  },
                },
                references = {
                  exclude = {},
                },
                rename = {
                  exclude = {},
                },
                index = {
                  static = true,
                },
                completion = {
                  fullyQualifyImportNames = true,
                },
              },
            })

            client:notify('workspace/didChangeConfiguration', { settings = client.settings })
          end

          require('keymaps').set_lsp_keymaps(event.buf, {
            lsp_references = builtin.lsp_references,
            lsp_implementations = builtin.lsp_implementations,
            lsp_definitions = builtin.lsp_definitions,
            lsp_type_definitions = builtin.lsp_type_definitions,
            lsp_document_symbols = function() builtin.lsp_document_symbols() end,
            lsp_dynamic_workspace_symbols = function() builtin.lsp_dynamic_workspace_symbols() end,
          })

          if client and client:supports_method('textDocument/documentHighlight', event.buf) then
            local highlight_augroup = vim.api.nvim_create_augroup('config-lsp-highlight', { clear = false })
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
              group = vim.api.nvim_create_augroup('config-lsp-detach', { clear = true }),
              callback = function(event2)
                vim.lsp.buf.clear_references()
                vim.api.nvim_clear_autocmds { group = 'config-lsp-highlight', buffer = event2.buf }
              end,
            })
          end

          if client and client:supports_method('textDocument/inlayHint', event.buf) then
            require('keymaps').set_lsp_inlay_hint_keymap(event.buf)
          end

        end,
      })

      ---@type table<string, vim.lsp.Config>
      local servers = {
        intelephense = {
          root_dir = helpers.project_root,
          settings = {
            intelephense = {
              files = {
                maxSize = 10000000,
                associations = { "*.php", "*.phtml" },
                exclude = {
                  "**/.git/**",
                  "**/node_modules/**",
                  "**/var/cache/**",
                },
              },
              references = {
                exclude = {},
              },
              rename = {
                exclude = {},
              },
              index = {
                static = true,
              },
              completion = {
                fullyQualifyImportNames = true,
              },
            },
          },
        },
        yamlls = {
          settings = {
            yaml = {
              customTags = symfony_yaml_custom_tags,
              keyOrdering = false,
              validate = true,
              hover = true,
              completion = true,
              format = { enable = true },
            },
          },
        },
        twiggy_language_server = {},
        ts_ls = {},
        lua_ls = {
          root_dir = helpers.project_root,
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
      table.insert(ensure_installed, 'stylua')

      require('mason-tool-installer').setup { ensure_installed = ensure_installed }

      local capabilities = require('blink.cmp').get_lsp_capabilities()
      local lspconfig = require 'lspconfig'

      require('mason-lspconfig').setup {
        ensure_installed = vim.tbl_keys(servers or {}),
        handlers = {
          function(server_name)
            local server = servers[server_name] or {}
            server.capabilities = vim.tbl_deep_extend('force', {}, capabilities, server.capabilities or {})
            lspconfig[server_name].setup(server)
          end,
        },
      }
    end,
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
            preference = { 'intelephense' },
          },
        }
    end,
  },
  {
    'phpactor/phpactor',
    version = '0.18.1',
    build = 'composer install --no-dev -o',
    ft = 'php',
    init = function()
      vim.api.nvim_create_autocmd('FileType', {
        desc = 'PHPActor keymaps',
        group = vim.api.nvim_create_augroup('config-phpactor-keymaps', { clear = true }),
        pattern = 'php',
        callback = function(args)
          vim.g.phpactorPhpBin = 'php'
          vim.g.phpactorbinpath = vim.fn.stdpath 'data' .. '/lazy/phpactor/bin/phpactor'
          require('keymaps').set_phpactor_keymaps(args.buf, run_phpactor_override)
        end,
      })
    end,
  },
}
