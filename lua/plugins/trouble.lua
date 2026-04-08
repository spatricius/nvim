return {
  'folke/trouble.nvim',
  cmd = 'Trouble',
  keys = {
    { '<leader>xx', '<cmd>Trouble diagnostics toggle<CR>', desc = 'Trouble [D]iagnostics' },
    { '<leader>xX', '<cmd>Trouble diagnostics toggle filter.buf=0<CR>', desc = 'Trouble [B]uffer diagnostics' },
    { '<leader>xq', '<cmd>Trouble qflist toggle<CR>', desc = 'Trouble [Q]uickfix list' },
    { '<leader>xl', '<cmd>Trouble loclist toggle<CR>', desc = 'Trouble [L]ocation list' },
    { '<leader>xr', '<cmd>Trouble lsp_references toggle focus=false<CR>', desc = 'Trouble LSP [R]eferences' },
    { '<leader>xi', '<cmd>Trouble lsp_implementations toggle focus=false<CR>', desc = 'Trouble LSP [I]mplementations' },
  },
  opts = {},
}
