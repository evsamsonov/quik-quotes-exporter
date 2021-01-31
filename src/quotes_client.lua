local QuotesClient = {}
function QuotesClient:new(params)
    local this = {}

    -- RPC клиент :required
    this.rpcClient = params.rpcClient

    --[[
        Возвращает последнюю свечу по инструменту
    --]]
    function this:getLastCandle(market, symbol, period)
        local response = this.rpcClient:sendRequest("Quotes.GetLastCandle", {
            market = market,
            symbol = symbol,
            period = period
        })
        if response.error ~= nil then
            error('failed to get last candle: ' .. response.error.message)
        end
        do return response.result end
    end

    setmetatable(this, self)
    self.__index = self
    return this
end