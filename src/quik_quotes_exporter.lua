local inspect = require('lib/inspect')

local QuotesClient = require('src/quotes_client')
local QuikMessage = require('src/quik_message')
local JsonRpcFileProxyClient = require('src/json_rpc_file_proxy_client')

local QuikQuotesExporter = {
    MOSCOW_EXCHANGE_MARKET = 1
}
function QuikQuotesExporter:new(params)
    local this = {}

    this.requiredParams = {
        'rpcClient',
        'instruments',
    }
    function this:checkRequiredParams(params)
        for i, key in ipairs(this.requiredParams) do
            if params[key] == nil then
                error('Required param ' .. key .. ' not set')
            end
        end
    end
    this:checkRequiredParams(params)

    this.instruments = params.instruments

    this.rpcClient = nil
    this.rpcClientRequestFilePath = params.rpcClient.requestFilePath
    this.rpcClientResponseFilePath = params.rpcClient.responseFilePath
    this.rpcClientPrefix = params.rpcClient["prefix"] and params.rpcClient["prefix"] or ""

    this.quotesClient = nil
    this.running = true

    --[[
        Создает источник данных графика
        @see https://quikluacsharp.ru/quik-qlua/poluchenie-v-qlua-lua-dannyh-iz-grafikov-i-indikatorov/
        @see https://quikluacsharp.ru/qlua-osnovy/spisok-konstant-tajm-frejmov-grafikov/

        @param string classCode     Код класса (например, SPBFUT)
        @param string instrument    Код бумаги (например, SRU0)
        @param interval             Интервал (например, INTERVAL_H1)

        @return DataSource
    --]]
    local function createDataSource(classCode, secCode, interval)
        local ds, err = CreateDataSource(classCode, secCode, interval)
        if err ~= nil then
            error(err)
        end

        -- Ждем, пока загрузятся данные
        local timeoutSec = 10
        local startTime = os.time()
        while ds:Size() == 0 do
            sleep(1000)
            if os.time() - startTime > timeoutSec then
                error('timeout expired')
            end
        end
        return ds
    end

    --[[
        Инициализация
    --]]
    local function init()
        this.rpcClient = JsonRpcFileProxyClient:new({
            requestFilePath = this.rpcClientRequestFilePath,
            responseFilePath = this.rpcClientResponseFilePath,
            prefix = this.rpcClientPrefix,
        })

        this.quotesClient = QuotesClient:new({
            rpcClient = this.rpcClient
        })

        for i, inst in ipairs(this.instruments) do
            local ds, status, err
            status, err = pcall(function()
                ds = createDataSource(inst.classCode, inst.secCode, inst.interval)
            end)
            if status == false then
                error(
                    'failed to create data source ' .. inst.classCode .. ', ' .. inst.secCode  .. ', ' .. inst.interval
                    .. ':' .. err
                )
            end

            this.instruments[i].dataSource = ds
            this.instruments[i].lastCandleTime = nil

            local result = this.quotesClient:getLastCandle(inst.market, inst.secCode, inst.interval)
            if result.candle ~= nil then
                this.instruments[i].lastCandleTime = result.candle.time
            end
        end
    end

    --[[
        Освобождение ресурсов
    --]]
    local function terminate()
        for i, inst in ipairs(this.instruments) do
            inst.dataSource:Close()
        end
    end

    --[[
        Проверяет необходимость обработать инструмент

        @param table inst

        @return bool
    --]]
    local function mustProcessInstrument(inst)
        local now = os.date("*t")
        if inst.interval == INTERVAL_H1 and (inst.lastProcessedDate == nil or now.hour ~= inst.lastProcessedDate.hour) then
            return true
        end
        return false
    end

    --[[
        Обрабатывает инструмент

        @param table inst
    --]]
    local function processInstrument(inst)
        for j = inst.dataSource:Size(), 1, -1 do
            if os.time(inst.dataSource:T(j)) >= inst.lastCandleTime then
                this.quotesClient:addCandle(inst.market, inst.secCode, inst.interval, {
                    time = os.time(inst.dataSource:T(j)),
                    high = inst.dataSource:H(j),
                    low = inst.dataSource:L(j),
                    open = inst.dataSource:O(j),
                    close = inst.dataSource:C(j),
                    volume = math.ceil(inst.dataSource:V(j)),
                })
                inst.lastCandleTime = os.time(inst.dataSource:T(j))
                inst.lastProcessedDate = os.date("*t")
            end
        end
    end

    --[[
        Обрабатывает список инструментов
    --]]
    local function processInstruments()
        for i, inst in pairs(this.instruments) do
            if mustProcessInstrument(inst) then
                processInstrument(inst)
            end
        end
    end

    --[[
        Запуск
    --]]
    function this:run()
        init()
        QuikMessage.show('QuikQuotesExporter has been started successfully', QuikMessage.QUIK_MESSAGE_INFO)

        while this.running do
            processInstruments()

            sleep(60 * 1000)
        end

        terminate()
    end

    --[[
        Остановка
    --]]
    function this:stop()
        this.running = false
    end

    setmetatable(this, self)
    self.__index = self
    return this
end

return QuikQuotesExporter