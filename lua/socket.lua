local server = require "resty.websocket.server"
local redis = require "resty.redis_iresty"
local cjson = require "cjson"
local util = require "lua.api.utils"
local resp = require "lua.api.models.response"

local response = resp:new()
local log = ngx.log
local ERR = ngx.ERR

local function subscribe(ws)
  local red = redis:new({timeout=1000})
  local func  = red:subscribe("orders.messages")
  if not func then
    ngx.say("failed to connect: ", err)
    return
  end
  while true do
    local bytes, err = func()
    if bytes then
      local bytes, err = ws:send_text(bytes[3])
      if not bytes then
        -- red:decrby('counter:access',1)
        --log(ERR, "failed to send a text frame: ", err)
        return ngx.exit(444)
      end
    end
  end
end

local ws, err = server:new{ timeout = 30000, max_payload_len = 65535 }
if not ws then
  log(ERR, "failed to new websocket: ", err)
  return ngx.exit(444)
end

-- 新建线程订阅聊天通道
ngx.thread.spawn(subscribe, ws)
local red = redis:new({timeout=1000})

while true do
  local bytes, typ, err = ws:recv_frame()
  if ws.fatal then return
  elseif not bytes then
      ws:send_ping()
  elseif typ == "close" then
    break
  elseif typ == "text"  then
    local msg = cjson.decode(bytes) -- 转义为json格式，获取type参数，判断消息类型
    log(ERR, msg.dsf)
    red:publish("orders.messages", cjson.encode(msg))
  end
end

local bytes, err = ws:send_close()
if not bytes then
    log(ERR, "failed to send the close frame: ", err)
    return
end