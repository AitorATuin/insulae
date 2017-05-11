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

------------
-- command
-- command class wrapping shell commands
-- classmod: command
-- author: AitorATuin
-- license:MIT

-- class table
local Command = {}

Command.__index = Command

--- forks the process creating a new child and spawn a new command on it
-- In the child process STDIN, STDOUT and STDERR are duplicated
-- table: argt argument list using posix.unistd.execp format
-- stdin: stdin STDIN fd to use in child process
-- stdout: stdout STDOUT fd to use in child process
-- stderr: stderr STDERR fd to use in child process
-- treturn: ?int|nil child process's pid or nil
-- treturn: ?string error string in case of error
local function fork_command(argt, stdin, stdout, stderr)
  local pid, errmsg = unistd.fork() 
  if not pid then return nil, errmsg end
  if pid == 0 then
    -- child process here, spawn a new command!
    unistd.dup2(stdout, unistd.STDOUT_FILENO)
    unistd.dup2(stderr, unistd.STDERR_FILENO)
    local exit_code, reason = posix.spawn(argt)
    os.exit(exit_code)
  else
    return pid, errmsg
  end
end

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
    local lstat = sys_stat.lstat(path)
    if lstat and can_be_executed(lstat.st_mode) then
      return candidate_path
    end
  end
  return nil
end

--- funtion that given a string creates a table with path and arguments ready
-- to be used by fork_command
-- treturn: ?table table with the path for command and the arguments for command
local function prepare_command(command)
  local cmdt = {}
  for item in command:gmatch('[^%s]+') do
    cmdt[#cmdt + 1] = item
  end
  if cmdt[1] then
    cmdt[1] = find_binary_path(cmdt[1])
    return cmdt
  end
  return nil
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

function Command.command(cmd)
  local command_wrapper = function(parameters, stdin)
    local stdout_r, stdout_w = posix.pipe()
    local stderr_r, stderr_w = posix.pipe()
    local argt = prepare_command(cmd)
    local child_pid, errmsg = fork_command(argt, nil, stdout_w, stderr_w)
    if not child_pid then 
      -- Error forking child!
      close_fds(stderr_r, stderr_w, stdout_r, stdout_w)
      return nil, 'Error forking command!'
    elseif child_pid ~= 0 then
      -- Child is running!
      close_fds(stdout_w, stderr_w)
      local _, reason, exit_code = sys_wait.wait(child_pid)
      local output_data = read_data(stdout_r)
      local err_data = read_data(stderr_r)
      close_fds(stdout_r, stderr_w)
      return output_data, err_data, exit_code
    end
  end
  return Command.fn(command_wrapper)
end

function Command.fn(command_fn)
  local t = {
    runner = command_fn
  }
  return setmetatable(t, Command)
end

function Command.run(self, params)
  stdout, stderr, exit_code = self.runner(parameter, self.stdin)
  return {
    exit_code = exit_code,
    stdout = stdout,
    stderr = stderr
  }
end

function Command.with_stdin(self, stdin)
  self.stdin = stdin
end

function Command.pipe(self, command)
  error 'No implemented'
  local piped_command = Command.fn(function (params)
    local result = self:prepare(result):run(params)
    return command:prepare(result):run(params)
  end)

  return piped_command
end

function Command.merge(self, ...)
  error 'No implemented'
  -- TODO: Check that commands are valid Commands
  local commands = {...}
  local merged_command = Command.fn(function(params)
    --- recursive coroutine gathering all the stdout/stderr from other commands
  end)

  return merged_command
end

return Command
