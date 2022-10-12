local QuotesClient = {
    BUY = 1,
    SELL = 2
}
function QuotesClient:new(params)
    local this = {}

    this.requiredParams = {
        'rpcClient'
    }
    function this:checkRequiredParams(params)
        for i, key in ipairs(this.requiredParams) do
            if params[key] == nil then
                error('Required param ' .. key .. ' not set')
            end
        end
    end
    this:checkRequiredParams(params)

    this.rpcClient = params.rpcClient

    local intervals = {
        [INTERVAL_M1] = 1,
        [INTERVAL_M5] = 2,
        [INTERVAL_M10] = 3,
        [INTERVAL_M15] = 4,
        [INTERVAL_M30] = 5,
        [INTERVAL_H1] = 6,
        [INTERVAL_D1] = 7,
        [INTERVAL_W1] = 8,
        [INTERVAL_MN1] = 9
    }

    --[[
        Возвращает последнюю свечу по инструменту
        @param int market
        @param string symbol
        @param int interval

        @return table = {
            candle (nullable) = {
                time        int         unix timestamp
                high        float
                low         float
                open        float
                close       float
                volume      int
            }
        }
    --]]
    function this:getLastCandle(market, symbol, interval)
        local response = this.rpcClient:sendRequest("Quotes.GetLastCandle", {
            market = market,
            symbol = symbol,
            interval = intervals[interval]
        })
        if response.error ~= nil then
            error('failed to get last candle: ' .. response.error.message)
        end
        do return response.result end
    end

    --[[
        Добавляет или обновляет свечу
        @param int market
        @param string symbol
        @param int interval
        @param table candle {
            time        int         unix timestamp
            high        float
            low         float
            open        float
            close       float
            volume      int
        }
    --]]
    function this:addCandle(market, symbol, interval, candle)
        local response = this.rpcClient:sendRequest("Quotes.AddCandle", {
            market = market,
            symbol = symbol,
            interval = intervals[interval],
            candle = candle
        })
        if response.error ~= nil then
            error('failed to add candle: ' .. response.error.message)
        end
    end

    --[[
        Добавляет тики
        @param int market
        @param string symbol
        @param array {
            tick {
                id          int
                time        int         unix timestamp
                price       float
                volume      float
                operation   int         1 - buy, 2 - sell
            }
        }
    --]]
    function this:addTicks(market, symbol, ticks)
        local response = this.rpcClient:sendRequest("Quotes.AddTicks", {
            market = market,
            symbol = symbol,
            ticks = ticks
        })
        if response.error ~= nil then
            error('failed to add ticks: ' .. response.error.message)
        end
    end

    --[[
        Отправляет оповещение
        @param string message
    --]]
    function this:notify(message)
        local response = this.rpcClient:sendRequest("Notification.Notify", {
            message = message
        })
        if response.error ~= nil then
            error('failed to notify: ' .. response.error.message)
        end
    end

    setmetatable(this, self)
    self.__index = self
    return this
end

return QuotesClient
