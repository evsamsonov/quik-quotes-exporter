local inspect = require('lib/inspect')

local QuotesClient = require('src/quotes-client')
local JsonRpcFileProxyClient = require('src/json_rpc_file_proxy_client')

local QuikQuotesProvider = {}
function QuikQuotesProvider:new(params)
    local this = {}

    -- Список инструментов, по которым сохранять котировки
    this.instruments = params.instruments

    -- RPC клиент
    this.rpcClient = nil
    this.rpcClientRequestFilePath = params.rpcClient.requestFilePath
    this.rpcClientResponseFilePath = params.rpcClient.responseFilePath

    this.quotesClient = nil

    -- Типы отображаемой иконки в сообщении терминала QUIK
    -- @see http://www.luaq.ru/message.html
    local QUIK_MESSAGE_INFO = 1
    local QUIK_MESSAGE_WARNING = 2
    local QUIK_MESSAGE_ERROR = 3

    -- Рынок
    local MOSCOW_EXCHANGE_MARKET = 1

    local function showQuikMessage(text, icon)
        if icon == nil then
            icon = QUIK_MESSAGE_INFO
        end
        message(text, icon)
    end

    --[[
        Создает источник данных

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
        for i, v in ipairs(this.instruments) do
            local ds, status, err
            status, err = pcall(function()
                ds = createDataSource(v.classCode, v.secCode, v.interval)
            end)
            if status == false then
                error('failed to create data source ' .. v.classCode .. ', ' .. v.secCode .. ', ' .. v.interval .. ':' .. err)
            end
            this.instruments[i].dataSource = ds
        end

        this.rpcClient = JsonRpcFileProxyClient:new({
            requestFilePath = this.rpcClientRequestFilePath,
            responseFilePath = this.rpcClientResponseFilePath,
        })

        this.quotesClient = QuotesClient:new({
            rpcClient = this.rpcClient
        })
    end

    local function sendCandles()
        for key, instrument in pairs(this.instruments) do

            -- todo получить с сервера дату последней свечи
            -- todo получить данные с источника
            -- todo отправить свежие данные на сервер
        end
    end


    function this:run()
        init()




        -- todo создаем график инструментов и отправляем периодически текущюю свечу и предыдущую (сколько раз???)
        -- todo подписываемся на таблицу с обезличенными сделками и сохраняем данные (на каждый тик или буферизируем??)
    end

    setmetatable(this, self)
    self.__index = self
    return this
end

return QuikQuotesProvider