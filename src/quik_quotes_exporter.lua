local QuotesClient = require('src/quotes_client')
local QuikMessage = require('src/quik_message')
local JsonRpcFSProxyClient = require('src/jsonrpc_fsproxy_client')
local inspect = require('lib/inspect')

local QuikQuotesExporter = {
    MOSCOW_EXCHANGE_MARKET = 1
}
function QuikQuotesExporter:new(params)
    local this = {}
    local VERSION = 'v1.0.3'
    local TICK_BATCH_SIZE = 500

    --[[
        Проверяет наличие обязательных параметров
        @param table params
        @param array requiredParams
    --]]
    function this:checkRequiredParams(params, requiredParams)
        for i, key in ipairs(requiredParams) do
            if params[key] == nil then
                error('Required param ' .. key .. ' not set')
            end
        end
    end
    this:checkRequiredParams(params, {
        'rpcClient',
        'instruments',
    })

    --[[
        Список обрабатываемых инструментов
        [
            {
                market int              Рынок
                classCode string        Код класса
                secCode string          Код инструмента
                interval int            Интервал
                lastCandleTime int      Время последней известной свечи в Unix Timestamp
                dataSource DataSource   Источник данных QUIK
                lotSize int             Размер лота
                trades table            Буфер для обезличенных сделок
            },
            ...
        ]
    ]]--
    this.instruments = params.instruments
    this.running = true
    this.quotesClient = QuotesClient:new({
        rpcClient = JsonRpcFSProxyClient:new({
            requestFilePath = params.rpcClient.requestFilePath,
            responseFilePath = params.rpcClient.responseFilePath,
            idPrefix = params.rpcClient['idPrefix'] and params.rpcClient['idPrefix'] or '',
        })
    })

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
        local message = 'QuikQuotesExporter ' .. VERSION .. ' has been started successfully'
        QuikMessage.show(message, QuikMessage.QUIK_MESSAGE_INFO)
        this.quotesClient:notify(os.date('%Y-%m-%d %X: ') .. message)
    end

    --[[
        Создает tick из trade
        @param table trade
        @param int lotSize

        @return table {
            id int
            time int
            price float
            volume int
            operation int
        }
    --]]
    local function createTick(trade, lotSize)
        local operation
        if bit.band(trade.flags, 0x1) == 0x1 then
            operation = QuotesClient.SELL
        elseif bit.band(trade.flags, 0x2) == 0x2 then
            operation = QuotesClient.BUY
        end
        return {
            id = trade.trade_num,
            time = os.time(trade.datetime),
            price = trade.price,
            volume = math.ceil(trade.qty * lotSize),
            operation = operation,
        }
    end

    --[[
        Отправляет все обезличенные сделки из таблицы сделок по полученному инструменту
        @param table inst   Инструмент
    ]]--
    local function sendAllTrades(inst)
        local batchSize = TICK_BATCH_SIZE
        local trade
        local ticks = {}
        local tradeCount = getNumberOf("all_trades")
        for i = 0, tradeCount - 1 do
            trade = getItem("all_trades", i)
            if trade.class_code == inst.classCode and trade.sec_code == inst.secCode then
                table.insert(ticks, createTick(trade, inst.lotSize))
            end
            if i == tradeCount - 1 or (i + 1) % batchSize == 0 then
                this.quotesClient:addTicks(inst.market, inst.secCode, ticks)
                ticks = {}
            end
        end
    end

    --[[
        Инициализация
    --]]
    local function init()
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
            inst.dataSource = ds
            inst.lastCandleTime = nil
            inst.lotSize = getParamEx(inst.classCode, inst.secCode, "lotsize").param_value
            inst.trades = {}

            -- Получение времени последней свечи с сервера
            local result = this.quotesClient:getLastCandle(inst.market, inst.secCode, inst.interval)
            if result.candle ~= nil then
                inst.lastCandleTime = result.candle.time
            end

            sendAllTrades(inst)
        end
        onInitialized()
    end

    --[[
        Завершение работы
    --]]
    local function terminate()
        for i, inst in ipairs(this.instruments) do
            inst.dataSource:Close()
        end
    end

    --[[
        Вызывает функцию и повторяет вызов переданное число раз при неуспехе
        @param func function
        @param timeout int      Таймаут между попытками в секундах
        @param count int        Кол-во повторений
    ]]--
    local function withRetry(func, timeout, count)
        timeout = (timeout ~= nil) and timeout or 10
        count = (count ~= nil) and count or 3
        local result, status
        for i = 1, count do
            status, result = pcall(function()
                return func()
            end)
            if status then
                do return result end
            end
            sleep(timeout * 1000)
        end
        error(result)
    end

    --[[
        Сообщает об ошибках
        @param string err
    ]]--
    local function reportError(err)
        local message = 'QuikQuotesExporter: ' .. err
        QuikMessage.show(message, QuikMessage.QUIK_MESSAGE_INFO)
        this.quotesClient:notify(os.date('%Y-%m-%d %X: ') .. message)
    end

    --[[
        Обрабатывает инструмент
        @param table inst
    --]]
    local function processInstrument(inst)
        if os.time(inst.dataSource:T(inst.dataSource:Size())) == inst.lastCandleTime then
            do return end
        end

        local status, result
        for j = inst.dataSource:Size(), 1, -1 do
            if os.time(inst.dataSource:T(j)) >= inst.lastCandleTime then
                status, result = pcall(function()
                    withRetry(function()
                        this.quotesClient:addCandle(inst.market, inst.secCode, inst.interval, {
                            time = os.time(inst.dataSource:T(j)),
                            high = inst.dataSource:H(j),
                            low = inst.dataSource:L(j),
                            open = inst.dataSource:O(j),
                            close = inst.dataSource:C(j),
                            volume = math.ceil(inst.dataSource:V(j) * inst.lotSize),
                        })
                    end)
                end)
                if not status then
                    reportError(result)
                end
            end
        end
        inst.lastCandleTime = os.time(inst.dataSource:T(inst.dataSource:Size()))
    end

    --[[
        Отправляет накопленные обезличенные сделки
        @param table inst
    --]]
    local function flushTrades(inst)
        local ticks = {}
        for _, trade in pairs(inst.trades) do
            table.insert(ticks, createTick(trade, inst.lotSize))
            inst.trades[trade.trade_num] = nil
        end

        local batchSize = TICK_BATCH_SIZE
        local batch = {}
        for i = 1, #ticks do
            table.insert(batch, ticks[i])
            if i == #ticks or i % batchSize == 0 then
                withRetry(function()
                    this.quotesClient:addTicks(inst.market, inst.secCode, batch)
                end)
                batch = {}
            end
        end
    end

    --[[
        Обрабатывает список инструментов
    --]]
    local function processInstruments()
        for _, inst in pairs(this.instruments) do
            processInstrument(inst)
            flushTrades(inst)
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
        local minute = 60 * 1000
        local status, err = pcall(function()
            init()

            while this.running do
                if isWorkingHour() then
                    processInstruments()
                end

                sleep(minute/4)
            end
        end)
        if status == false then
            reportError(err)
        end

        terminate()
    end

    --[[
        Остановка
    --]]
    function this:stop()
        this.running = false
    end

    --[[
        Обработка обезличенной сделки
    --]]
    function this:onTrade(trade)
        for i, inst in ipairs(this.instruments) do
            if trade.class_code == inst.classCode and trade.sec_code == inst.secCode then
                if inst.trades ~= nil then
                    inst.trades[trade.trade_num] = trade
                    break
                end
            end
        end
    end

    setmetatable(this, self)
    self.__index = self
    return this
end

return QuikQuotesExporter
