local resp = require "lua.api.models.response"
local cjson = require "cjson.safe"
local redis = require "resty.redis_iresty"
local utils = require "lua.api.utils"
local method = ngx.req.get_method()
local response = resp:new()
local log = ngx.log
local ERR = ngx.ERR
local red, err = redis:new({timeout=1000})
if not red or err then
  response.code = "0001"
  response.desc = "系统错误，请稍后再试"
  ngx.say(cjson.encode(response))
  return
end

if method == "POST" then
  ngx.req.read_body()
  local orders = cjson.decode(ngx.req.get_body_data())
  local time = ngx.time()
  local items = {}
  for i in pairs(orders) do
    local item = {}
    local order = orders[i]
    item['name'] = order.name
    item['sweetness'] = order.sweetness
    item['temperature'] = order.temperature
    item['tableNo'] = order.tableNo
    table.insert(items, item)
    red:eval([[
      local id = redis.call("incr","autoincr:ordersid")
      redis.call("hmset", "orders:" .. id, "tableNo", KEYS[1], "name", KEYS[2], "sweetness", KEYS[3], "temperature", KEYS[4], "price", KEYS[5])
      redis.call("zadd","orders", KEYS[6], id)
    ]], 6, order.tableNo, order.name, order.sweetness, order.temperature, order.price, time)
  end
  local message = {}
  message['items'] = items
  message['tableNo'] = items[1].tableNo
  -- log(ERR, cjson.encode(message))
  red:publish("orders.messages", cjson.encode(message))
  response.code = 200
  response.data = orders
  response.desc = 'success'
  ngx.say(cjson.encode(response))
end