local cmd = require('insulae.command').command
local sys_stat = require('posix.sys.stat')

local function mock_path(path, mocked_field, mocked_modules)
  local module_path, field = string.match(path, '(.+)%.(%w+)$')
  if field then
    -- mock that field
    local mod = package.loaded[module_path]
    local orig_field = mod[field]
    mod[field] = mocked_field
    mocked_modules[field] = {mod, orig_field}
  end
end

local function mock_reset(mocked_modules)
  for field, mod in pairs(mocked_modules) do
    mod[1][field] = mod[2]
  end
end

local mocked_modules = {}

describe('insulae.command specs', function()

  -- some mocked functions
  local function mock_path_env(_)
    return '/some/bin/path'
  end

  local function mock_lstat(mode)
    local modes = {
      exec = function (_)
        return {
          st_mode = sys_stat.S_IXUSR
        }
      end,
      noexec = function (_)
        return {
          st_mode = sys_stat.S_IRUSR
        }
      end,
      dir = function (_)
        return {
          st_mode = bit32.bor(sys_stat.S_IFDIR, sys_stat.S_IXUSR)
        }
      end
    }
    return modes[mode] or function (_) return nil end
  end

  -- mock PATH env for each test
  before_each(function()
    mock_path('os.getenv', mock_path_env, mocked_modules) 
  end)

  -- Reset all mocks after each test
  after_each(function()
    mock_reset(mocked_modules)
  end)

  describe('should be able to create new commands', function()
    it('create a command if command is in path and is executable', function()
      mock_path('posix.sys.stat.lstat', mock_lstat('exec'), mocked_modules)

    end)

    it('returns nil and error message if command is not in path', function ()
      mock_path('posix.sys.stat.lstat', mock_lstat(), mocked_modules)
      local cmd1, errmsg = cmd('some_command')
      assert.is_nil(cmd1)
      assert.are.equals(errmsg, 'command some_command not found')
    end)

    it('return nil and error message if command is in path but not executable', function ()
      mock_path('posix.sys.stat.lstat', mock_lstat('noexec'), mocked_modules)
      local cmd1, errmsg = cmd('some_command')
      assert.is_nil(cmd1)
      assert.are.equals(errmsg, 'command some_command not found')
    end)

    it('return nil and error message if command is in path, is executable but a directory', function ()
      mock_path('posix.sys.stat.lstat', mock_lstat('dir'), mocked_modules)
      local cmd1, errmsg = cmd('some_command')
      assert.is_nil(cmd1)
      assert.are.equals(errmsg, 'command some_command not found')
    end)

    it('new commands can show a string representation', function ()
      mock_path('posix.sys.stat.lstat', mock_lstat('exec'), mocked_modules)
      local cmd1 = cmd('some_command -a -vv param1 param2')
      local cmd2 = cmd('some_other_command param2')
      assert.are.equals(tostring(cmd1), 'some_command -a -vv param1 param2')
      assert.are.equals(tostring(cmd2), 'some_other_command param2')
    end)

    it('create a command from a function', function ()
      local cmd1 = cmd(function() return "output" end)
      assert.is_not_nil(cmd1)
    end)

    it('returns nil and error if we create a command from other type', function ()
      local cmd1, errmsg1 = cmd({})
      local cmd2, errmsg2 = cmd(true)
      local cmd3, errmsg3 = cmd(666)
      assert.is_nil(cmd1)
      assert.are.equals(errmsg1, 'Commands can not be created from a table')
      assert.is_nil(cmd2)
      assert.are.equals(errmsg2, 'Commands can not be created from a boolean')
      assert.is_nil(cmd3)
      assert.are.equals(errmsg3, 'Commands can not be created from a number')
    end)
  end)

  describe('should be able to pipe commands', function()
    mock_path('posix.sys.stat.lstat', mock_lstat('exec'), mocked_modules)
    local cmd1 = cmd('cmd1 -a -b -c')
    local cmd2 = cmd('cmd2 file')
    local piped1 = cmd1 | cmd2
    local piped2 = cmd1 | cmd('program in the middle') | cmd2
    assert.is_not_nil(piped1)
    assert.is_not_nil(piped2)
  end)

  describe('should be able to execute commands', function()
    it('commands are not executed if any param is not resolved', function ()
      pending('Test not implemented')  
    end)

    it('commands are executed when all params are resolved', function ()
      pending('Test not implemented')      
    end)
  end)
end)
