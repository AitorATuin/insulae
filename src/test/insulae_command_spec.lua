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
    }
    return modes[mode] or function (_) return nil end
  end

  -- Reset all mocks after each test
  after_each(function()
    mock_reset(mocked_modules)
  end)

  describe('should be able to create new commands', function()
    it('create a command if command is in path and is executable', function()
      mock_path('posix.sys.stat.lstat', mock_lstat('exec'), mocked_modules)
      mock_path('os.getenv', mock_path_env, mocked_modules) 
      assert.is_not_nil(cmd('some_command'))
    end)

    it('returns nil and error message if command is not in path', function ()
      local cmd1, errmsg = cmd('some_command')
      mock_path('posix.sys.stat.lstat', mock_lstat(), mocked_modules)
      assert.is_nil(cmd1)
      assert.are.equals(errmsg, 'command some_command not found')
    end)

    it('return nil and error message if command is in path but not executable', function ()
      pending('Test not implemented') 
    end)

    it('new commands can show a string representation', function ()
      pending('Test not implemented')  
    end)

    it('create a command from a function', function ()
      pending('Test not implemented')      
    end)

    it('returns nil and error if we create a command from other type', function ()
      pending('Test not implemented')      
    end)
  end)

  describe('should be able to pipe commands', function()
    pending('Test not implemented')
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
