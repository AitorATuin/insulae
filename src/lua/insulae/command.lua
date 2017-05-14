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

--- funtion that given a string creates a table with path and arguments ready
-- to be used by fork_command
-- treturn: ?table table with the path for command and the arguments for command
local function prepare_command(command)
  local cmdt = {}
  local err = nil
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
  return cmdt
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

------------
-- command
-- command class wrapping shell commands
-- classmod: command
-- author: AitorATuin
-- license: GPL3

-- class table
local Command = {}

local function wrap_command(cmd)
  local command_wrapper = function(parameters, stdin)
    local stdout_r, stdout_w = posix.pipe()
    local stderr_r, stderr_w = posix.pipe()
    local stdin_r, stdin_w = nil
    if stdin then
      stdin_r, stdin_w = posix.pipe()
      unistd.write(stdin_w, stdin)
      close_fds(stdin_w)
    end
    local child_pid, errmsg = fork_command(cmd, stdin_r, stdout_w, stderr_w)
    if not child_pid then 
      -- Error forking child!
      close_fds(stderr_r, stderr_w, stdout_r, stdout_w, stdin_r, stdin_w)
      return {
        stdout = "",
        stderr = errmsg,
        exit_code = 127
      }
    elseif child_pid ~= 0 then
      -- Child is running!
      close_fds(stdout_w, stderr_w, stdin_r)
      local _, reason, exit_code = sys_wait.wait(child_pid)
      local output_data = read_data(stdout_r)
      local err_data = read_data(stderr_r)
      close_fds(stdout_r, stderr_r)
      return {
        stdout = output_data,
        stderr = err_data,
        exit_code = exit_code
      }
    end
  end
  return command_wrapper
end


function Command.run(self, params)
  return self._runner(parameter, self.stdin)
end

function Command.with_stdin(self, stdin)
  self.stdin = stdin
  return self
end

function Command.pipe(self, other)
  if not eq_mt(self, other) then
    print("SASS")
    return nil, 'Only commands can be piped, second argument is not an Command'
  end
  local piped_command = Command.new(function (params)
    local result = self:run()
    if result.exit_code == 0 then
      return other:with_stdin(result.stdout):run()
    else
      return result
    end
  end)

  return piped_command
end

function Command.tostring(self)
  return printf("Command")
end

function Command.merge(self, ...)
  error 'No implemented'
  -- TODO: Check that commands are valid Commands
  local commands = {...}
  local merged_command = Command.new(function(params)
    --- recursive coroutine gathering all the stdout/stderr from other commands
  end)

  return merged_command
end

function Command.new(command)
  local command_fn = nil
  if type(command) == 'function' then
    command_fn = command
  else
    command_fn = wrap_command(command)
  end
  local t = {
    _runner = command_fn
  }
  return setmetatable(t, Command)
end

Command.__index = function(_, f)
  if f == 'new' then return nil end
  return Command[f]
end
Command.__call = Command.run
Command.__div = Command.pipe
Command.__tostring = Command.tostring



return {
  command = Command.new
}
