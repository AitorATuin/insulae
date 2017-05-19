------------
-- insulae.command
-- module to run shell commands in a nice way
-- module: insulae.command
-- author: AitorATuin
-- license: MIT

local posix = require 'posix'
local unistd = require 'posix.unistd'
local sys_wait = require 'posix.sys.wait'
local sys_stat = require 'posix.sys.stat'
local result = require 'insulae.result'
local printf = string.format

--- resolves path for program `binary` using $PATH
-- treturn: ?string|nil path for an executable program `binary`
local function find_binary_path(binary)
  local function can_be_executed(st_mode)
    return bit32.band(st_mode, sys_stat.S_IXUSR) == sys_stat.S_IXUSR and
      bit32.band(st_mode, sys_stat.S_IFDIR) ~= sys_stat.S_IFDIR
  end
  local paths = os.getenv('PATH')
  local binary_path = nil
  for path in paths:gmatch('[^:]+') do
    local candidate_path = path .. '/' .. binary
    local lstat = sys_stat.lstat(candidate_path)
    if lstat and can_be_executed(lstat.st_mode) then
      return candidate_path
    end
  end
  return nil, printf('command %s not found', binary)
end

local function prepare_params(argt)
  local function add_index(t, field, idx)
    local tt = (t[field] or {})
    tt[#tt+1] = idx
    return tt
  end
  -- argt[1] has always the command, ignore it
  local p = {}
  for i=2, #argt do
    for capture in string.gmatch(argt[i], "${([%w-_]+)}") do
      p[capture] = add_index(p, capture, i)
    end
  end
  return setmetatable(argt, {
    __index = function(t, v)
      return p[v]
    end
  })
end

--- funtion that given a string creates a table with path and arguments ready
-- to be used by fork_command
-- treturn: ?table table with the path for command and the arguments for command
local function prepare_command(command)
  local cmdt = {}
  local err = nil
  if type(command) ~= 'function' and type(command) ~= 'string' then
    return nil, printf('Commands can not be created from a %s', type(command))
  end
  for item in command:gmatch('[^%s]+') do
    cmdt[#cmdt + 1] = item
  end
  if not cmdt[1] then
    return nil, 'command not specified!'
  end
  cmdt[1], err = find_binary_path(cmdt[1])
  if not cmdt[1] then
    return nil, err
  end
  return prepare_params(cmdt)
end

--- reads all available data for fd
-- treturn: string string containing the data in fd
local function read_data(fd)
  local buffer = 2048
  local function rec_read_data(fd, data, count)
    if count < buffer then
      return data
    else
      local _data = unistd.read(fd, buffer)
      return rec_read_data(fd, data .. _data, #_data)
    end
  end
  return rec_read_data(fd, "", buffer)
end

--- closes a bunch of fds
local function close_fds(...)
  local fds = {...}
  for _, fd in ipairs(fds) do
    unistd.close(fd)
  end
end

--- forks the process creating a new child and spawn a new command on it
-- In the child process STDIN, STDOUT and STDERR are duplicated
-- table: argt argument list using posix.unistd.execp format
-- stdin: stdin STDIN fd to use in child process
-- stdout: stdout STDOUT fd to use in child process
-- stderr: stderr STDERR fd to use in child process
-- treturn: ?int|nil child process's pid or nil
-- treturn: ?string error string in case of error
local function fork_command(cmd, stdin, stdout, stderr)
  local argt, errmsg = prepare_command(cmd)
  if not argt then
    return nil, errmsg
  end
  local pid, errmsg = unistd.fork() 
  if not pid then return nil, errmsg end
  if pid == 0 then
    -- child process here, spawn a new command!
    unistd.dup2(stdout, unistd.STDOUT_FILENO)
    unistd.dup2(stderr, unistd.STDERR_FILENO)
    if stdin then
      unistd.dup2(stdin, unistd.STDIN_FILENO)
    end
    local exit_code, reason = posix.spawn(argt)
    os.exit(exit_code)
  else
    return pid, errmsg
  end
end

-- Compares two object metatables
function eq_mt(obj1, obj2)
  return getmetatable(obj1) == getmetatable(obj2)
end

-- Join params
function merge_params(params1, params2)
  local t = {}
  for k, v in pairs(params1) do
    t[k] = v
  end
  for k, v in pairs(params2) do
    t[k] = v
  end
  return t
end

------------
-- command
-- command class wrapping shell commands
-- classmod: command
-- author: AitorATuin
-- license: GPL3

-- class table
local Command = {}

local function wrap_function(fn)
  return function(params, stdin) return fn(params) end
end

local function wrap_command(cmd)
  local argt, errmsg = prepare_command(cmd)
  if not argt then
    return nil, errmsg
  end
  local command_wrapper = function(curernt_patams, params)
    local stdout_r, stdout_w = posix.pipe()
    local stderr_r, stderr_w = posix.pipe()
    local stdin_r, stdin_w = nil
    if (current_params or {}).stdin then
      stdin_r, stdin_w = posix.pipe()
      unistd.write(stdin_w, current_params.stdin)
      close_fds(stdin_w)
    end
    local child_pid, errmsg = fork_command(cmd, stdin_r, stdout_w, stderr_w)
    if not child_pid then 
      -- Error forking child!
      close_fds(stderr_r, stderr_w, stdout_r, stdout_w, stdin_r, stdin_w)
      return result('', errmsg, 127)
    elseif child_pid ~= 0 then
      -- Child is running!
      close_fds(stdout_w, stderr_w, stdin_r)
      local _, reason, exit_code = sys_wait.wait(child_pid)
      local output_data = read_data(stdout_r)
      local err_data = read_data(stderr_r)
      close_fds(stdout_r, stderr_r)
      return result(output_data, err_data, exit_code)
    end
  end
  return command_wrapper, argt 
end

function Command.run(self, params)
    return self._runner(params)
end

function Command.pipe(self, other)
  if not eq_mt(self, other) then
    return nil, 'Only commands can be piped, second argument is not an Command'
  end
  local command_fn = function (params)
    local result = self:run()
    if result.exit_code == 0 then
      params = params or {}
      params.stdin = result.stdout
      return other:run(params)
    else
      return result.stdout, result.stderr, result.exit_code
    end
  end

  local params = merge_params(self._params, other._params)

  return Command.new(function() return piped_command, params end)
end

function Command.tostring(self)
  if not self._params or not self._params[1] then
    return printf('Command: %s', self._runner)
  else
    local cmd = self._params[1][1]
    for i=2, #cmd do
      cmd = printf("%s %s", cmd, self._params[1][i])
    end
    return printf("Command %s", self._params[1][1])
  end
end

--- Creates a new Command
-- The argument `command` can be a string representing the command to execute
-- (with optional arguments) like "ls -la" or a function which must return:
-- (string, string, int) [(stdout, stderr, exit_code)
--
-- string|function: command command or function to execute
-- treturn: Command
function Command.new(command, params)
  local command_fn = nil
  if type(command) == 'function' then
    -- If command is a function we can pass optionaly a list of params
    command_fn = command
  else
    -- Function to run the command and parameters to resolve before
    -- running th command
    command_fn, params = wrap_command(command)
  end
  if not command_fn then
    -- params contains error string in case of error
    return nil, params
  end
  local t = {
    _runner = command_fn,
    _params = {
      params
    }
  }
  return setmetatable(t, Command)
end

Command.__index = function(_, f)
  if f == 'new' then return nil end
  return Command[f]
end
Command.__call = Command.run
if _VERSION == 'Lua 5.3' then
  Command.__bor = Command.pipe
else
  Command.__div = Command.pipe
end
Command.__tostring = Command.tostring

return {
  command = Command.new
}
