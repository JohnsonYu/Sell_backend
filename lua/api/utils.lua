local _M = {
  _VERSION = '0.1'
}
local mt = { __index = _M }
local saltStr = ngx.md5('salt')

local bit = require("bit")  
local bit_band = bit.band  
local bit_bor = bit.bor  
local bit_lshift = bit.lshift  
local string_format = string.format  
local string_byte = string.byte  
local table_concat = table.concat  
  
function _M.unicode_to_utf8(convertStr)
    if type(convertStr)~="string" then
        return convertStr
    end
    local resultStr=""
    local i=1
    while true do
        local num1=string.byte(convertStr,i)
        local unicode
        if num1~=nil and string.sub(convertStr,i,i+1)=="\\u" then
            unicode=tonumber("0x"..string.sub(convertStr,i+2,i+5))
            i=i+6
        elseif num1~=nil then
            unicode=num1
            i=i+1
        else
            break
        end

        if unicode <= 0x007f then
            resultStr=resultStr..string.char(bit.band(unicode,0x7f))
        elseif unicode >= 0x0080 and unicode <= 0x07ff then
            resultStr=resultStr..string.char(bit.bor(0xc0,bit.band(bit.rshift(unicode,6),0x1f)))
            resultStr=resultStr..string.char(bit.bor(0x80,bit.band(unicode,0x3f)))
        elseif unicode >= 0x0800 and unicode <= 0xffff then
            resultStr=resultStr..string.char(bit.bor(0xe0,bit.band(bit.rshift(unicode,12),0x0f)))   
            resultStr=resultStr..string.char(bit.bor(0x80,bit.band(bit.rshift(unicode,6),0x3f)))    
            resultStr=resultStr..string.char(bit.bor(0x80,bit.band(unicode,0x3f)))
        end
    end
    return resultStr
end

function _M.utf8_to_unicode(str)  
    if not str or str == "" or str == ngx.null then  
        return nil  
    end  
    local res, seq, val = {}, 0, nil  
    for i = 1, #str do  
        local c = string_byte(str, i)  
        if seq == 0 then  
            if val then  
                res[#res + 1] = string_format("%04x", val)  
            end
           seq = c < 0x80 and 1 or c < 0xE0 and 2 or c < 0xF0 and 3 or  
                              c < 0xF8 and 4 or --c < 0xFC and 5 or c < 0xFE and 6 or  
                              0  
            if seq == 0 then  
                ngx.log(ngx.ERR, 'invalid UTF-8 character sequence' .. ",,," .. tostring(str))  
                return str  
            end  
  
            val = bit_band(c, 2 ^ (8 - seq) - 1)  
        else  
            val = bit_bor(bit_lshift(val, 6), bit_band(c, 0x3F))  
        end  
        seq = seq - 1  
    end  
    if val then  
        res[#res + 1] = string_format("%04x", val)  
    end  
    if #res == 0 then  
        return str  
    end  
    return "\\u" .. table_concat(res, "\\u")  
end  

function _M.print_table(t)
  local function parse_array(key,tab)
    local str = ''
    for k, v in pairs(tab) do
      str = str .. k .. '  ' .. v ..'\r\n'
    end
    return str
  end

  local  str = ''
  for k,v in pairs(t) do
    if type(v) == 'table' then
      str = str .. parse_array(k, v)
    elseif type(v) == "boolean" then
            str = str .. k .. '  ' .. tostring(v) ..'\r\n'
        else
      str = str .. k .. '  ' .. (v) ..'\r\n'
    end
  end
  return str
end

function _M.use_time( fun , ...)
  ngx.update_time()
  local start_time = ngx.now()

  local res,err = fun(...)
  ngx.update_time()
  
  return res, err, ngx.now() - start_time
end

function _M.gen_password( pwd )
  return ngx.md5(pwd .. saltStr)
end

function _M.get_salt()
  return saltStr
end

function _M.string_split(s, p)
    local rt= {}
    string.gsub(s, '[^'..p..']+', function(w) table.insert(rt, w) end )
    return rt
end

--遍历父级分类
function _M.fathers( cat,red,tab )
    --通过传入的catId,循环遍历出所有的分类的父级id号
    local info = {}
    --一直遍历到顶级分类,顶级分类的分类id号为0,不如没有遍历到0就一直遍历 
    while cat ~= "0" do
        table.insert(info,cat)
        cat = red:hget(tab .. cat,"pid")
        if not tonumber(cat) then
            --如果cat为nil,说明上级分类被删除或者不存在了 退出循环,以免无限循环
            return
        end
    end
    --再把0(顶级分类加进去)
    table.insert(info,"0")
    --组合成字符串,方便eval遍历
    info = table.concat(info,",")
    return info
end

return _M
-- location ~* /api/([\w_+?])\.json {
--  content_by_lua_file lua/$1.lua;
-- }