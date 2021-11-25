--
-- Client for https://github.com/evsamsonov/jsonrpc-fsproxy
--
-- How to use
--
--   local rpcClient, status, err
--   status, err = pcall(function()
--      rpcClient = JsonRpcFSProxyClient:new({
--          requestFilePath = 'rpcin',
--          responseFilePath = 'rpcout',
--          requestTimeout = 60
--          reopenOnRequest = true
--      })
--   end)
--   if false == status then
--      print(err)
--      do return end
--   end
--
--   local result
--   status, err = pcall(function()
--      result = rpcClient:sendRequest('Method', {
--          param1 = 'value1'
--          param2 = 'value2'
--      })
--   end)
--   if false == status then
--      print(err)
--      do return end
--   end
--
--   rpcClient:close()
--
local json = require('./lib/json')

local JsonRpcFSProxyClient = {}
function JsonRpcFSProxyClient:new(params)
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
    this.idPrefix = params['idPrefix'] and params['idPrefix'] or ''

    -- Reopen request file on each request
    this.reopenOnRequest = (type(params.reopenOnRequest) ~= 'nil' and {params.reopenOnRequest} or {true})[1]

    local function openRequestFile()
        this.requestFile = io.open(this.requestFilePath, 'a')
        if this.requestFile == nil then
            error('Failed open request file')
        end
    end

    local function openFiles(params)
        if not this.reopenOnRequest then
            openRequestFile()
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
            local file = io.open(tmpLockFileName, 'w')
            if file ~= nil then
                file:close()
                if os.rename(tmpLockFileName, lockFileName) then
                    return function()
                        os.remove(lockFileName)
                    end
                end
            end
            sleep(1000)
        end
        error('Get lock timeout')
    end

    -- Sends json rpc request and returns response
    function this:sendRequest(method, params)
        if this.reopenOnRequest then
            openRequestFile()
        end

        local releaseLock = getLock()

        this.currentId = this.currentId + 1
        local id = this.idPrefix .. this.currentId
        local request = json:encode({
            jsonrpc = '2.0',
            method = method,
            params = params,
            id = id
        })
        this.requestFile:write(request .. '\n')
        this.requestFile:flush()
        if this.reopenOnRequest then
            this.requestFile:close()
        end

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
                error('Request timeout, id ' .. id .. ' ' .. os.date('!%Y-%m-%d-%H:%M:%S GMT', os.time()))
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

return JsonRpcFSProxyClient
