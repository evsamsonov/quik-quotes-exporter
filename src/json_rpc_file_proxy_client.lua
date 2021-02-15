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
--          requestFilePath = 'request.pipe',
--          responseFilePath = 'response.pipe',
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
--      openSignal = rpcClient:sendRequest('Method', {
--          param1 = 'param1'
--          param2 = 'param2'
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

    this.requiredParams = {
        'requestFilePath',
        'responseFilePath',
    }
    function this:checkRequiredParams(params)
        for i, key in ipairs(this.requiredParams) do
            if params[key] == nil then
                error('Required param ' .. key .. ' not set')
            end
        end
    end
    this:checkRequiredParams(params)

    this.requestFilePath = params.requestFilePath
    this.responseFilePath = params.responseFilePath

    -- Current ID for request
    this.currentId = 0

    -- How long to wait for response
    this.requestTimeout = params['requestTimeout'] and params['requestTimeout'] or 30

    -- Prefix for ID
    this.prefix = params['prefix'] and params['prefix'] or ''

    local function openFiles(params)
        this.requestFile = io.open(params.requestFilePath, 'a')
        if this.requestFile == nil then
            error('Failed open request file')
        end

        this.responseFile = io.open(params.responseFilePath, 'r')
        if this.responseFile == nil then
            error('Failed open response file')
        end
        this.responseFile:seek('end', 0)
    end
    openFiles(params)

    local function closeFiles()
        this.requestFile:close()
        this.responseFile:close()
    end

    --[[
        Get lock on request file
    --]]
    local function getLock()
        for i = 0, 30 do
            local lockFileName = this.requestFilePath .. '.lock'
            local tmpLockFileName = lockFileName .. 'tmp'
            io.open(tmpLockFileName, 'w'):close()

            if os.rename(tmpLockFileName, lockFileName) then
                return function()
                    os.remove(lockFileName)
                end
            end
            sleep(1000)
        end
        error('Get lock timeout')
    end

    -- Sends json rpc request and returns response
    function this:sendRequest(method, params)
        local releaseLock = getLock()

        this.currentId = this.currentId + 1
        local id = this.prefix .. this.currentId
        local request = json:encode({
            jsonrpc = '2.0',
            method = method,
            params = params,
            id = id
        })
        this.requestFile:write(request .. '\n')
        this.requestFile:flush()

        releaseLock()

        local response
        local time = os.time()
        while response == nil do
            sleep(100)
            for jsonLine in this.responseFile:lines() do
                local line = json:decode(jsonLine)
                if line.id == id then
                    response = line
                end
            end
            if os.difftime(os.time(), time) > this.requestTimeout then
                error('Request timeout')
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
