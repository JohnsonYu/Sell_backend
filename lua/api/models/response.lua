local _M = {
  _VERSION = '0.1'
}
local mt = { __index = _M }

function _M.new()
  local self = {}
  self.code = ''
  self.desc = ''
  self.data = {}
  return setmetatable(self, mt)
end

return _M