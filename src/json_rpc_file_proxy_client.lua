--
-- Client for https://github.com/evsamsonov/jsonrpc-fsproxy
--
-- How to use
--
--   local pcallStatus, pcallError
--
--   local rpcClient
--   pcallStatus, pcallError = pcall(function()
--      rpcClient = JsonRpcFileProxyClient:new({
--          requestFilePath = "request.pipe",
--          responseFilePath = "response.pipe",
--          requestTimeout = 60
--      })
--   end)
--   if false == pcallStatus then
--      print(pcallError.message)
--      do return end
--   end
--
--   local openSignal
--   pcallStatus, pcallError = pcall(function()
--      openSignal = rpcClient:sendRequest("Method", {
--          param1 = "param1"
--          param2 = "param2"
--      })
--   end)
--   if false == pcallStatus then
--      print(pcallError.message)
--      do return end
--   end
--
--   rpcClient:close()
--
local json = require('./lib/json')

local JsonRpcFileProxyClient = {}
function JsonRpcFileProxyClient:new(params)
    local this = {}

    -- Current ID for request
    this.currentId = 0

    -- How long to wait for response
    this.requestTimeout = params["requestTimeout"] and params["requestTimeout"] or 300

    local function openFiles(params)
        this.requestFile = io.open(params.requestFilePath, "a")
        if this.requestFile == nil then
            error({
                message = "JsonRpcFileProxyClient: failed open request file"
            })
        end

        this.responseFile = io.open(params.responseFilePath, "r")
        if this.responseFile == nil then
            error({
                message = "JsonRpcFileProxyClient: failed open response file"
            })
        end
        this.responseFile:seek("end", 0)
    end
    openFiles(params)

    local function closeFiles()
        this.requestFile:close()
        this.responseFile:close()
    end

    -- Sends json rpc request and returns response
    function this:sendRequest(method, params)
        this.currentId = this.currentId + 1
        local request = json:encode({
            jsonrpc = "2.0",
            method = method,
            params = params,
            id = this.currentId
        })
        this.requestFile:write(request .. "\n")
        this.requestFile:flush()

        local response
        local time = os.time()
        while response == nil do
            sleep(100)
            for jsonLine in this.responseFile:lines() do
                local line = json:decode(jsonLine)
                if line.id == this.currentId then
                    response = line
                end
            end
            if os.difftime(os.time(), time) > this.requestTimeout then
                error({
                    message = "JsonRpcFileProxyClient: request timeout"
                })
            end
        end
        do return response end
    end

    function this:close()
        closeFiles()
    end

    setmetatable(this, self)
    self.__index = self
    return this
end

return JsonRpcFileProxyClient
