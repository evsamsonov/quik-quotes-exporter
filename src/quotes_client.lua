local inspect = require('lib/inspect')

local QuotesClient = {}
function QuotesClient:new(params)
    local this = {}

    -- todo ошибка, если не переданы обязательные поля

    -- RPC клиент :required
    this.rpcClient = params.rpcClient

    local intervals = {
        [INTERVAL_H1] = 6
        -- todo прописать все интервалы
    }

    --[[
        Возвращает последнюю свечу по инструменту
        @param int market
        @param string symbol
        @param int interval
        @return table = {
            candle (nullable) = {
                time        int
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
            time        string in RFC3339
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

    setmetatable(this, self)
    self.__index = self
    return this
end

return QuotesClient