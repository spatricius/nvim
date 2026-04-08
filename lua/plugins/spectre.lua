return {
  'nvim-pack/nvim-spectre',
  cmd = 'Spectre',
  dependencies = { 'nvim-lua/plenary.nvim' },
  keys = {
    {
      '<leader>sR',
      function() require('spectre').toggle() end,
      desc = '[S]earch project [R]eplace',
    },
    {
      '<leader>sp',
      function() require('spectre').open_file_search { select_word = true } end,
      desc = '[S]earch current file re[P]lace',
    },
    {
      '<leader>sW',
      function() require('spectre').open_visual { select_word = true } end,
      desc = '[S]earch current [W]ord replace',
    },
    {
      '<leader>sW',
      function() require('spectre').open_visual() end,
      mode = 'v',
      desc = '[S]earch selection replace',
    },
  },
  opts = {
    use_trouble_qf = true,
  },
}
