local QuikQuotesProvider = require('src/quik_quotes_provider')

local quikQuotesProvider
function main()
    quikQuotesProvider = QuikQuotesProvider:new({
        rpcClient = {
            requestFilePath = 'Z:\\dev\\rpcin',
            responseFilePath = 'Z:\\dev\\rpcout'
        },
        instruments = {
            {
                market = MOSCOW_EXCHANGE_MARKET,
                classCode = 'TQBR',
                secCode = 'SBER',
                interval = INTERVAL_H1,
            }
        }

    })
    quikQuotesProvider:run()
end

-- На получение статуса транзакции
--function OnTransReply(transactionReply)
--    if quikDealer then
--        quikDealer:onTransactionReply(transactionReply)
--    end
--end
