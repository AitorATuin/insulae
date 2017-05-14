------------
-- result
-- resut from commands
-- classmod: result
-- author: AitorATuin
-- license: GPL3

local sprintf = string.format

-- class table
local Result = {}

Result.__index = Result

Result.new = function(stdout, stderr, exit_code)
  return setmetatable({
    stdout = stdout,
    stderr = stderr,
    exit_code = exit_code
  }, Result)
end

Result.tostring = function(self)
  if self.exit_code > 0 then
    return sprintf(self.stderr)
  else
    return sprintf(self.stdout)
  end
end

Result.__tostring = Result.tostring

return setmetatable({
  result = Result.new
}, {
  __call = function (_, ...) return Result.new(table.unpack({...})) end
})
