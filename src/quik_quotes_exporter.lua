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

    --[[
        Часы работы скрипта включително. По умолчанию без ограничений
        table (nullable) = {
           start int
           finish int
        }
    --]]
    this.workingHours = params["workingHours"] and params["workingHours"] or nil
    if this.workingHours ~= nil then
        if this.workingHours.start == nil  then
            error('Required param workingHours.start not set')
        end
        if this.workingHours.finish == nil then
            error('Required param workingHours.finish not set')
        end
        if this.workingHours.start < 0 or this.workingHours.start > 23  then
            error('Required param workingHours.start should be from 0 to 23')
        end
        if this.workingHours.finish < 0 or this.workingHours.finish > 23  then
            error('Required param workingHours.finish should be from 0 to 23')
        end
    end

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
        На завершение инициализации
    --]]
    local function onInitialized()
        local message = 'QuikQuotesExporter has been started successfully'
        QuikMessage.show(message, QuikMessage.QUIK_MESSAGE_INFO)
        this.quotesClient:notify(os.date('%Y-%m-%d %X: ') .. message)
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
            -- Создание источника данных
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

            -- Получение времени последней свечи с сервера
            local result = this.quotesClient:getLastCandle(inst.market, inst.secCode, inst.interval)
            if result.candle ~= nil then
                this.instruments[i].lastCandleTime = result.candle.time
            end

            -- Выгрузка всех имеющихся тиков
            local trade, operation
            local ticks = {}
            local lotSize = getParamEx(inst.classCode, inst.secCode, "lotsize").param_value
            local tradeCount = getNumberOf("all_trades")
            for i = 0, tradeCount - 1 do
                trade = getItem("all_trades", i)
                if trade.class_code == inst.classCode and trade.sec_code == inst.secCode then
                    if bit.band(trade.flags, 0x1) == 0x1 then
                        operation = QuotesClient.SELL
                    elseif bit.band(trade.flags, 0x2) == 0x2 then
                        operation = QuotesClient.BUY
                    end

                    table.insert(ticks, {
                        id = trade.trade_num,
                        time = os.time(trade.datetime),
                        price = trade.price,
                        volume = math.ceil(trade.qty * lotSize),
                        operation = operation,
                    })
                end
                if i == tradeCount - 1 or (i + 1) % 500 == 0 then
                    this.quotesClient:addTicks(inst.market, inst.secCode, ticks)
                    ticks = {}
                end
            end
        end

        onInitialized()
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
            end
        end
        inst.lastCandleTime = os.time(inst.dataSource:T(inst.dataSource:Size()))
        inst.lastProcessedDate = os.date("*t")
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
        @return bool
    --]]
    local function isWorkingHour()
        if this.workingHours == nil then
            do return true end
        end
        local now = os.date("*t")
        if this.workingHours.start <= this.workingHours.finish then
            do return now.hour >= this.workingHours.start and now.hour <= this.workingHours.finish end
        end
        -- if start > finish
        do return now.hour >= this.workingHours.start or now.hour <= this.workingHours.finish end
    end

    --[[
        Запуск
    --]]
    function this:run()
        local status, err = pcall(function()
            init()

            while this.running do
                if isWorkingHour() then
                    processInstruments()
                end

                sleep(60 * 1000)
            end

            terminate()
        end)
        if status == false then
            local message = 'QuikQuotesExporter: ' .. err
            QuikMessage.show(message, QuikMessage.QUIK_MESSAGE_ERROR)
            this.quotesClient:notify(os.date('%Y-%m-%d %X: ') .. message)
        end
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