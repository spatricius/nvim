local M = {}

local excluded_dirs = { 'node_modules', 'var' }

local function is_absolute_path(path)
  return type(path) == 'string' and (path:match '^/' ~= nil or path:match '^%a:[/\\]' ~= nil)
end

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
    if line:gsub('%s+', ''):lower() == 'root=true' then return true end
  end

  return false
end

local function is_project_root(dir)
  for _, marker in ipairs(project_root_markers) do
    if vim.uv.fs_stat(vim.fs.joinpath(dir, marker)) ~= nil then return true end
  end

  return editorconfig_has_root(dir)
end

function M.project_root(path)
  if type(path) == 'number' then
    path = vim.api.nvim_buf_get_name(path)
  end

  if path == nil or path == '' then return vim.fn.getcwd() end

  local stat = vim.uv.fs_stat(path)
  local dir = stat and stat.type == 'file' and vim.fs.dirname(path) or path
  if dir == '' then return vim.fn.getcwd() end

  dir = vim.fs.normalize(dir)
  local root = nil

  while dir and dir ~= '' do
    if is_project_root(dir) then root = dir end

    local parent = vim.fs.dirname(dir)
    if parent == dir then break end
    dir = parent
  end

  return root or vim.fn.getcwd()
end

function M.composer_bin_dir(path)
  local root = M.project_root(path)
  local composer_json = vim.fs.joinpath(root, 'composer.json')

  if vim.uv.fs_stat(composer_json) == nil then return vim.fs.joinpath(root, 'vendor', 'bin') end

  local ok, lines = pcall(vim.fn.readfile, composer_json)
  if not ok then return vim.fs.joinpath(root, 'vendor', 'bin') end

  local decoded_ok, composer = pcall(vim.json.decode, table.concat(lines, '\n'))
  if not decoded_ok or type(composer) ~= 'table' then return vim.fs.joinpath(root, 'vendor', 'bin') end

  local configured = composer.config and composer.config['bin-dir']
  if type(configured) ~= 'string' or configured == '' then return vim.fs.joinpath(root, 'vendor', 'bin') end

  if is_absolute_path(configured) then return configured end

  return vim.fs.joinpath(root, configured)
end

function M.symfony_console_path(path)
  local root = M.project_root(path)
  local docker_console = vim.fs.joinpath(root, 'bin', 'console-docker')
  if vim.uv.fs_stat(docker_console) ~= nil then return docker_console, root end

  local console = vim.fs.joinpath(root, 'bin', 'console')
  if vim.uv.fs_stat(console) ~= nil then return console, root end

  return nil
end

function M.symfony_console_command(path, args, opts)
  local console, root = M.symfony_console_path(path)
  if console == nil then return nil end

  args = args or {}
  opts = opts or {}

  local cmd = { console }
  vim.list_extend(cmd, args)

  return cmd, root
end

function M.excluded_globs()
  local globs = {}

  for _, dir in ipairs(excluded_dirs) do
    table.insert(globs, ('**/%s/**'):format(dir))
  end

  return globs
end

function M.phpactor_exclude_patterns()
  local patterns = {}

  for _, dir in ipairs(excluded_dirs) do
    table.insert(patterns, ('%s/**/*'):format(dir))
    table.insert(patterns, ('%s/**'):format(dir))
  end

  return patterns
end

function M.telescope_file_ignore_patterns(opts)
  local patterns = opts and opts.include_git and { '^.git/' } or {}

  for _, dir in ipairs(excluded_dirs) do
    table.insert(patterns, ('^%s/'):format(dir))
    table.insert(patterns, ('/%s/'):format(dir))
  end

  return patterns
end

function M.telescope_grep_additional_args()
  local args = { '--no-ignore' }

  for _, glob in ipairs(M.excluded_globs()) do
    table.insert(args, '--glob=!' .. glob)
  end

  return args
end

return M
